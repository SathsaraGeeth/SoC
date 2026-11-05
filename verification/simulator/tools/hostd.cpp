#include "hostd.hpp"
#include <iostream>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <thread>
#include <atomic>
#include <cstring>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>

#include <termios.h>
#include <csignal>

namespace fs = std::filesystem;

namespace hostd {

constexpr uint8_t MAGIC = 0x02;

static void send_frame(int fd, const std::vector<uint8_t>& data) {
    uint8_t magic = MAGIC;
    if (write(fd, &magic, 1) != 1) {
        throw std::runtime_error("Failed to write frame magic");
    }
    if (!data.empty()) {
        size_t sent = 0;
        while (sent < data.size()) {
            ssize_t n = write(fd, data.data() + sent, data.size() - sent);
            if (n <= 0) {
                throw std::runtime_error("Failed to write frame payload");
            }
            sent += static_cast<size_t>(n);
        }
    }
}

static void send_frame_str(int fd, const std::string& str) {
    send_frame(fd, std::vector<uint8_t>(str.begin(), str.end()));
}

static std::string read_line(int fd) {
    std::string buf;
    while (true) {
        char c;
        ssize_t n = read(fd, &c, 1);
        if (n <= 0) {
            throw std::runtime_error("EOF on UART stream");
        }
        if (c == '\n') break;
        buf += c;
    }
    // Trim trailing \r if present
    if (!buf.empty() && buf.back() == '\r') {
        buf.pop_back();
    }
    return buf;
}

static void read_until_magic(int fd) {
    while (true) {
        uint8_t b;
        ssize_t n = read(fd, &b, 1);
        if (n <= 0) {
            throw std::runtime_error("EOF on UART stream");
        }
        if (b == MAGIC) {
            return;
        }
        // Transparently print kernel output to host stdout
        std::cout << (char)b << std::flush;
    }
}

void serve(const std::string& root_dir, int uart_rx_fd, int uart_tx_fd) {
    // Spawns a background thread to forward stdin to the simulator
    std::atomic<bool> running{true};
    std::thread stdin_thread([uart_tx_fd, &running]() {
        char c;
        while (running && read(STDIN_FILENO, &c, 1) > 0) {
            if (write(uart_tx_fd, &c, 1) <= 0) {
                break;
            }
        }
    });
    stdin_thread.detach();

    try {
        while (true) {
            read_until_magic(uart_rx_fd);
            std::string line = read_line(uart_rx_fd);
            if (line.empty()) continue;

            size_t space_idx = line.find(' ');
            std::string cmd = line.substr(0, space_idx);
            std::string path = (space_idx != std::string::npos) ? line.substr(space_idx + 1) : "/";
            
            // Remove leading slash for local path construction
            if (!path.empty() && path[0] == '/') {
                path = path.substr(1);
            }
            fs::path full_path = fs::path(root_dir) / path;

            if (cmd == "HOST_PING") {
                send_frame_str(uart_tx_fd, "PONG\n");
            } 
            else if (cmd == "HOST_READ") {
                try {
                    std::ifstream f(full_path, std::ios::binary | std::ios::ate);
                    if (!f) throw std::runtime_error("Cannot open file");
                    std::streamsize size = f.tellg();
                    f.seekg(0, std::ios::beg);
                    
                    std::vector<uint8_t> data(size);
                    if (f.read(reinterpret_cast<char*>(data.data()), size)) {
                        std::vector<uint8_t> response(4 + size);
                        uint32_t s = size;
                        std::memcpy(response.data(), &s, 4);
                        std::memcpy(response.data() + 4, data.data(), size);
                        send_frame(uart_tx_fd, response);
                    } else {
                        throw std::runtime_error("Read failed");
                    }
                } catch (...) {
                    uint32_t zero = 0;
                    std::vector<uint8_t> err(4);
                    std::memcpy(err.data(), &zero, 4);
                    send_frame(uart_tx_fd, err);
                }
            }
            else if (cmd == "HOST_WRITE") {
                try {
                    size_t last_space = path.find_last_of(' ');
                    uint32_t size = 0;
                    std::string actual_path = path;
                    if (last_space != std::string::npos) {
                        actual_path = path.substr(0, last_space);
                        size = std::stoul(path.substr(last_space + 1));
                    }
                    
                    std::vector<uint8_t> data(size);
                    size_t read_bytes = 0;
                    while (read_bytes < size) {
                        ssize_t n = read(uart_rx_fd, data.data() + read_bytes, size - read_bytes);
                        if (n <= 0) throw std::runtime_error("EOF during WRITE data");
                        read_bytes += n;
                    }

                    fs::path fp = fs::path(root_dir) / actual_path;
                    fs::create_directories(fp.parent_path());
                    std::ofstream f(fp, std::ios::binary);
                    f.write(reinterpret_cast<char*>(data.data()), size);
                    send_frame_str(uart_tx_fd, "OK\n");
                } catch (...) {
                    send_frame_str(uart_tx_fd, "ERR\n");
                }
            }
            else if (cmd == "HOST_LS") {
                try {
                    for (const auto& entry : fs::directory_iterator(full_path)) {
                        std::string name = entry.path().filename().string();
                        if (entry.is_directory()) name += "/";
                        send_frame_str(uart_tx_fd, name + "\n");
                    }
                } catch (...) {}
                send_frame_str(uart_tx_fd, "END\n");
            }
            else if (cmd == "HOST_MKDIR") {
                try {
                    fs::create_directories(full_path);
                    send_frame_str(uart_tx_fd, "OK\n");
                } catch (...) {
                    send_frame_str(uart_tx_fd, "ERR\n");
                }
            }
            else if (cmd == "HOST_RM") {
                try {
                    if (fs::is_directory(full_path)) {
                        fs::remove_all(full_path);
                    } else {
                        fs::remove(full_path);
                    }
                    send_frame_str(uart_tx_fd, "OK\n");
                } catch (...) {
                    send_frame_str(uart_tx_fd, "ERR\n");
                }
            }
            else if (cmd == "HOST_STAT") {
                try {
                    if (fs::exists(full_path)) {
                        std::string ftype = fs::is_directory(full_path) ? "D" : "F";
                        uintmax_t size = fs::file_size(full_path);
                        send_frame_str(uart_tx_fd, ftype + " " + std::to_string(size) + "\n");
                    } else {
                        send_frame_str(uart_tx_fd, "ERR\n");
                    }
                } catch (...) {
                    send_frame_str(uart_tx_fd, "ERR\n");
                }
            }
            else {
                std::cout << "[kernel] " << line << "\n" << std::flush;
            }
        }
    } catch (const std::exception& e) {
        std::cerr << "[hostd] error: " << e.what() << "\n";
    }
    running = false;
}

static struct termios old_settings;
static bool is_tty_saved = false;
static pid_t child_pid = 0;

static void handle_sigint(int sig) {
    if (is_tty_saved) {
        tcsetattr(STDIN_FILENO, TCSADRAIN, &old_settings);
    }
    if (child_pid > 0) {
        kill(child_pid, SIGTERM);
        int status;
        waitpid(child_pid, &status, 0);
    }
    std::cout << "\n[hostd] Exiting gracefully.\n";
    exit(0);
}

int serve_with_subprocess(const std::string& root_dir, const std::vector<std::string>& cmd_args) {
    std::string stdout_log;
    std::vector<std::string> args = cmd_args;

    for (size_t i = 0; i < args.size(); ++i) {
        if (args[i] == "--stdout-log" && i + 1 < args.size()) {
            stdout_log = args[i + 1];
            args.erase(args.begin() + i, args.begin() + i + 2);
            break;
        }
    }

    int uart_pipe[2];
    int stdin_pipe[2];
    if (pipe(uart_pipe) == -1 || pipe(stdin_pipe) == -1) {
        perror("pipe");
        return 1;
    }

    pid_t pid = fork();
    if (pid == -1) {
        perror("fork");
        return 1;
    }

    if (pid == 0) {
        // Child
        close(uart_pipe[0]);
        close(stdin_pipe[1]);
        
        int flags = fcntl(uart_pipe[1], F_GETFD);
        fcntl(uart_pipe[1], F_SETFD, flags & ~FD_CLOEXEC);
        setenv("UART_TX_FD", std::to_string(uart_pipe[1]).c_str(), 1);

        dup2(stdin_pipe[0], STDIN_FILENO);
        close(stdin_pipe[0]);

        if (!stdout_log.empty()) {
            int fd = open(stdout_log.c_str(), O_WRONLY | O_CREAT | O_APPEND, 0666);
            if (fd != -1) {
                dup2(fd, STDOUT_FILENO);
                dup2(fd, STDERR_FILENO);
                close(fd);
            }
        }

        std::vector<char*> c_args;
        for (const auto& a : args) c_args.push_back(const_cast<char*>(a.c_str()));
        c_args.push_back(nullptr);

        execvp(c_args[0], c_args.data());
        perror("execvp");
        exit(1);
    } else {
        // Parent
        close(uart_pipe[1]);
        close(stdin_pipe[0]);
        
        child_pid = pid;
        std::signal(SIGINT, handle_sigint);
        std::signal(SIGTERM, handle_sigint);

        struct termios new_settings;
        is_tty_saved = isatty(STDIN_FILENO);
        if (is_tty_saved) {
            tcgetattr(STDIN_FILENO, &old_settings);
            new_settings = old_settings;
            new_settings.c_lflag &= ~(ICANON | ECHO);
            tcsetattr(STDIN_FILENO, TCSANOW, &new_settings);
        }

        serve(root_dir, uart_pipe[0], stdin_pipe[1]);

        if (is_tty_saved) {
            tcsetattr(STDIN_FILENO, TCSADRAIN, &old_settings);
        }

        int status;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status)) {
            std::cout << "\n[hostd] dsim exited with code " << WEXITSTATUS(status) << "\n";
            return WEXITSTATUS(status);
        } else if (WIFSIGNALED(status)) {
            std::cout << "\n[hostd] dsim killed by signal " << WTERMSIG(status) << "\n";
            return 128 + WTERMSIG(status);
        }
    }
    return 0;
}

} // namespace hostd
