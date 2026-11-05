#include "Vsoc.h"
#include "Vsoc___024root.h"
#include "verilated.h"
#include <iostream>
#include <stdexcept>
#include <chrono>
#include <iomanip>
#include <vector>
#include <array>
#include <cstdio>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <signal.h>
#include <poll.h>
#include "verilated_save.h"
#include "block_storage.h"

volatile bool finish_requested = false;
volatile sig_atomic_t debug_dump_requested = 0;

static constexpr unsigned FB_WIDTH = 32;
static constexpr unsigned FB_HEIGHT = 32;
static std::vector<uint8_t> framebuffer(FB_WIDTH * FB_HEIGHT, 0);
static bool framebuffer_dirty = false;

extern "C" void sim_framebuffer_write(uint64_t offset, uint8_t value) {
    if (offset < framebuffer.size()) {
        framebuffer[static_cast<size_t>(offset)] = value;
        framebuffer_dirty = true;
    }
}

static void put_u16le(FILE *out, uint16_t value) {
    fputc(value & 0xff, out);
    fputc((value >> 8) & 0xff, out);
}

static void put_u32le(FILE *out, uint32_t value) {
    for (unsigned shift = 0; shift < 32; shift += 8)
        fputc((value >> shift) & 0xff, out);
}

static void write_framebuffer_bmp() {
    if (!framebuffer_dirty) return;
    FILE *out = fopen("framebuffer.bmp.tmp", "wb");
    if (!out) return;
    const uint32_t row_bytes = (FB_WIDTH * 3u + 3u) & ~3u;
    const uint32_t pixel_bytes = row_bytes * FB_HEIGHT;
    fputc('B', out); fputc('M', out);
    put_u32le(out, 54u + pixel_bytes);
    put_u32le(out, 0); put_u32le(out, 54);
    put_u32le(out, 40); put_u32le(out, FB_WIDTH);
    /* Negative height makes the BMP top-down, matching the framebuffer. */
    put_u32le(out, static_cast<uint32_t>(-static_cast<int32_t>(FB_HEIGHT)));
    put_u16le(out, 1); put_u16le(out, 24);
    put_u32le(out, 0); put_u32le(out, pixel_bytes);
    put_u32le(out, 2835); put_u32le(out, 2835);
    put_u32le(out, 0); put_u32le(out, 0);
    for (unsigned y = 0; y < FB_HEIGHT; ++y) {
        for (unsigned x = 0; x < FB_WIDTH; ++x) {
            const uint8_t p = framebuffer[y * FB_WIDTH + x];
            const uint8_t r = (uint8_t)(((p >> 5) & 7u) * 255u / 7u);
            const uint8_t g = (uint8_t)(((p >> 2) & 7u) * 255u / 7u);
            const uint8_t b = (uint8_t)((p & 3u) * 255u / 3u);
            fputc(b, out); fputc(g, out); fputc(r, out);
        }
        for (uint32_t pad = FB_WIDTH * 3u; pad < row_bytes; ++pad) fputc(0, out);
    }
    fclose(out);
    rename("framebuffer.bmp.tmp", "framebuffer.bmp");
    framebuffer_dirty = false;
}

// The framebuffer is ordinary region-0 SRAM, read directly from Verilator's
// generated model state.  No framebuffer behavior is present in RTL.
static void refresh_framebuffer_from_sram(Vsoc* top) {
    auto* r = top->rootp;
    const std::array<const QData*, 16> bank = {
#define FB_BANK(n) &r->soc__DOT__gen_cluster__BRA__0__KET____DOT__memory_u__DOT__genblk1__BRA__##n##__KET____DOT__sram_bank_u__DOT__mem[0]
        FB_BANK(0), FB_BANK(1), FB_BANK(2), FB_BANK(3), FB_BANK(4), FB_BANK(5), FB_BANK(6), FB_BANK(7),
        FB_BANK(8), FB_BANK(9), FB_BANK(10), FB_BANK(11), FB_BANK(12), FB_BANK(13), FB_BANK(14), FB_BANK(15)
#undef FB_BANK
    };
    constexpr uint64_t base = 0x00100000;
    constexpr uint64_t bank_span = 16 * sizeof(QData);
    for (size_t offset = 0; offset < framebuffer.size(); ++offset) {
        const uint64_t addr = base + offset;
        const uint8_t value = static_cast<uint8_t>(
            bank[(addr / sizeof(QData)) % bank.size()][addr / bank_span] >> ((addr % sizeof(QData)) * 8));
        if (framebuffer[offset] != value) {
            framebuffer[offset] = value;
            framebuffer_dirty = true;
        }
    }
}

void handle_sigint(int sig) {
    finish_requested = true;
}

void handle_sigusr1(int) {
    debug_dump_requested = 1;
}

#include <stdlib.h>

static void write_uart_byte(char data) {
    static int fd = -1;
    if (fd == -1) {
        const char* fd_str = getenv("UART_TX_FD");
        if (fd_str) fd = atoi(fd_str);
        else fd = 3; // Fallback
    }
    if (write(fd, &data, 1) != 1) {
        finish_requested = true;
    }
}

static unsigned uart_baud_div(const Vsoc* top) {
    return top->rootp
        ->soc__DOT__uart_mmio_inst__DOT__uart_u__DOT__r_baud_div;
}

static void drive_uart_rx(Vsoc* top) {
    static int frame_bit = -1;
    static unsigned cycles_left = 0;
    static unsigned bit_cycles = 16;
    static uint8_t data = 0;

    if (frame_bit < 0) {
        unsigned char input;
        if (read(STDIN_FILENO, &input, 1) != 1) {
            top->i_uart_rx = 1;
            return;
        }
        data = input;
        frame_bit = 0;
        bit_cycles = (uart_baud_div(top) / 16) * 16;
        cycles_left = bit_cycles;
    }

    if (frame_bit == 0) {
        top->i_uart_rx = 0;
    } else if (frame_bit <= 8) {
        top->i_uart_rx = (data >> (frame_bit - 1)) & 1u;
    } else {
        top->i_uart_rx = 1;
    }

    if (--cycles_left == 0) {
        if (frame_bit == 9) {
            frame_bit = -1;
        } else {
            ++frame_bit;
            cycles_left = bit_cycles;
        }
    }
}

static void sample_uart_tx(Vsoc* top) {
    static bool previous = true;
    static int bit = -1;
    static unsigned phase = 0;
    static unsigned bit_cycles = 16;
    static uint8_t data = 0;
    const bool tx = top->o_uart_tx;
    if (bit < 0) {
        if (previous && !tx) {
            bit = 0;
            bit_cycles = uart_baud_div(top);
            phase = bit_cycles + bit_cycles / 2;
            data = 0;
        }
    } else {
        if (phase > 0) --phase;
        if (phase == 0) {
            if (bit < 8) {
                if (tx) data |= static_cast<uint8_t>(1u << bit);
                ++bit;
                phase = bit_cycles;
            } else {
                write_uart_byte(static_cast<char>(data));
                bit = -1;
            }
        }
    }
    previous = tx;
}

static void read_file_or_throw(FILE* file, uint8_t* buf, int64_t size, const char* path) {
    if (size < 0) {
        throw std::runtime_error(std::string("Negative file size for ") + path);
    }
    if (fread(buf, 1, static_cast<size_t>(size), file) != static_cast<size_t>(size)) {
        throw std::runtime_error(std::string("Failed to read ") + path);
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    

    // Set stdin to non-blocking
    int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);

    // hostd supplies stdin through a pipe.  Only change terminal settings
    // when the simulator is launched directly from an interactive terminal.
    struct termios oldt {};
    const bool stdin_is_tty = isatty(STDIN_FILENO) && tcgetattr(STDIN_FILENO, &oldt) == 0;
    if (stdin_is_tty) {
        struct termios newt = oldt;
        newt.c_lflag &= ~(ICANON | ECHO);
        tcsetattr(STDIN_FILENO, TCSANOW, &newt);
    }

    signal(SIGINT, handle_sigint);
    signal(SIGTERM, handle_sigint);
    signal(SIGHUP, handle_sigint);
#ifndef _WIN32
    signal(SIGPIPE, SIG_IGN);
    signal(SIGUSR1, handle_sigusr1);
#endif

    bool restore = false;
    for (int i = 1; i < argc; i++) {
        if (std::string(argv[i]) == "--restore") {
            restore = true;
            break;
        }
    }

#ifndef FLASH_SIZE
#define FLASH_SIZE (16 * 1024 * 1024)
#endif

#ifndef BL2_BASE_BA
#define BL2_BASE_BA 0x20010000
#endif

#ifndef BL2A_BASE_BA
#define BL2A_BASE_BA 0x20018000
#endif

#ifndef KERNEL_BASE_BA
#define KERNEL_BASE_BA 0x20020000
#endif

#ifndef FS_BASE_BA
#define FS_BASE_BA 0x20098000
#endif

#ifndef CLOCK_FREQ_HZ
#define CLOCK_FREQ_HZ 1000000000ULL
#endif

    Vsoc* top = new Vsoc;
    PageEngineModel* page_engine = new PageEngineModel(FLASH_SIZE);
    uint64_t cycle = 0;
    
    FILE* f_bl2 = fopen("block_storage/bl2.bin", "rb");
    if (f_bl2) {
        fseek(f_bl2, 0, SEEK_END);
        int64_t fsize = ftell(f_bl2);
        fseek(f_bl2, 0, SEEK_SET);
        uint8_t* buf = new uint8_t[fsize + 8];
        memset(buf, 0, fsize + 8);
        read_file_or_throw(f_bl2, buf, fsize, "block_storage/bl2.bin");
        fclose(f_bl2);
        
        uint64_t base_addr = BL2_BASE_BA;
        for (int64_t i = 0; i < fsize; i += 8) {
            uint64_t val = 0;
            for (int j = 0; j < 8; j++) {
                val |= ((uint64_t)buf[i + j]) << (j * 8);
            }
            page_engine->memory[(base_addr + i) / 8] = val;
        }
        delete[] buf;
        std::cout << "Loaded bl2.bin into Block Storage at 0x" << std::hex << base_addr << std::dec << " (size " << fsize << " bytes)" << std::endl;
    } else {
        std::cerr << "Failed to open block_storage/bl2.bin" << std::endl;
    }

    FILE* f_bl2a = fopen("block_storage/bl2A.bin", "rb");
    if (f_bl2a) {
        fseek(f_bl2a, 0, SEEK_END);
        int64_t fsize = ftell(f_bl2a);
        fseek(f_bl2a, 0, SEEK_SET);
        uint8_t* buf = new uint8_t[fsize + 8];
        memset(buf, 0, fsize + 8);
        read_file_or_throw(f_bl2a, buf, fsize, "block_storage/bl2A.bin");
        fclose(f_bl2a);
        
        uint64_t base_addr = BL2A_BASE_BA;
        for (int64_t i = 0; i < fsize; i += 8) {
            uint64_t val = 0;
            for (int j = 0; j < 8; j++) {
                val |= ((uint64_t)buf[i + j]) << (j * 8);
            }
            page_engine->memory[(base_addr + i) / 8] = val;
        }
        delete[] buf;
        std::cout << "Loaded bl2A.bin into Block Storage at 0x" << std::hex << base_addr << std::dec << " (size " << fsize << " bytes)" << std::endl;
    } else {
        std::cerr << "Failed to open block_storage/bl2A.bin" << std::endl;
    }

    FILE* f_kernel = fopen("block_storage/kernel.bin", "rb");
    if (f_kernel) {
        fseek(f_kernel, 0, SEEK_END);
        int64_t fsize = ftell(f_kernel);
        fseek(f_kernel, 0, SEEK_SET);
        uint8_t* buf = new uint8_t[fsize + 8];
        memset(buf, 0, fsize + 8);
        read_file_or_throw(f_kernel, buf, fsize, "block_storage/kernel.bin");
        fclose(f_kernel);
        
        uint64_t base_addr = KERNEL_BASE_BA;
        for (int64_t i = 0; i < fsize; i += 8) {
            uint64_t val = 0;
            for (int j = 0; j < 8; j++) {
                val |= ((uint64_t)buf[i + j]) << (j * 8);
            }
            page_engine->memory[(base_addr + i) / 8] = val;
        }
        delete[] buf;
        std::cout << "Loaded kernel.bin into Block Storage at 0x" << std::hex << base_addr << std::dec << " (size " << fsize << " bytes)" << std::endl;
    } else {
        std::cerr << "Failed to open block_storage/kernel.bin" << std::endl;
    }

    FILE* f_fs = fopen("block_storage/fs.bin", "rb");
    if (f_fs) {
        fseek(f_fs, 0, SEEK_END);
        int64_t fsize = ftell(f_fs);
        fseek(f_fs, 0, SEEK_SET);
        uint8_t* buf = new uint8_t[fsize + 8];
        memset(buf, 0, fsize + 8);
        read_file_or_throw(f_fs, buf, fsize, "block_storage/fs.bin");
        fclose(f_fs);
        
        uint64_t base_addr = FS_BASE_BA;
        for (int64_t i = 0; i < fsize; i += 8) {
            uint64_t val = 0;
            for (int j = 0; j < 8; j++) {
                val |= ((uint64_t)buf[i + j]) << (j * 8);
            }
            page_engine->memory[(base_addr + i) / 8] = val;
        }
        delete[] buf;
        std::cout << "Loaded fs.bin into Block Storage at 0x" << std::hex << base_addr << std::dec << " (size " << fsize << " bytes)" << std::endl;
    } else {
        std::cerr << "Failed to open block_storage/fs.bin (continuing without fs)" << std::endl;
    }

    if (f_kernel) {
        std::cout << "\r";
        std::cout << "\n\n";

        std::cout <<
        "DDDDDD    M     M   DDDDD   TTTTTTT   PPPPPP\n\r"
        "D     D   MM   MM   D          T      P     P\n\r"
        "D     D   M M M M   D          T      P     P\n\r"
        "D     D   M  M  M   D          T      PPPPPP\n\r"
        "D     D   M     M   D          T      P\n\r"
        "DDDDDD    M     M   DDDDD      T      P\n\r"
        "\n\r"
        "==================== RUNNING =====================\n\n";
        std::cout << std::endl;
        std::cout << "\r";
    } else {
        std::cerr << "Failed to open block_storage/kernel.bin — kernel will not run" << std::endl;
    }

    if (restore) {
        VerilatedRestore os;
        os.open("checkpoints/checkpoint.vls");
        os >> *top;
        os >> cycle;
        std::cout << "Restored simulation state from checkpoints/checkpoint.vls" << std::endl;
    } else {
        top->i_rst_n = 0;
        top->i_uart_rx = 1;
        
        for (int i=0; i<10; i++) {
            top->i_clk = 0; top->eval();
            top->i_clk = 1; top->eval();
        }
        top->i_rst_n = 1;
    }

    const uint64_t start_cycle = cycle;
    const auto wall_start = std::chrono::steady_clock::now();
    /* Create a valid black frame immediately, so the web viewer never has a
     * broken image while the target is booting or drawing its first frame. */
    refresh_framebuffer_from_sram(top);
    framebuffer_dirty = true;
    write_framebuffer_bmp();

    while (!Verilated::gotFinish() && !finish_requested) {
        page_engine->eval(top);
        drive_uart_rx(top);
        top->i_clk = 0;
        top->eval();
        
        top->i_clk = 1;
        top->eval();
        sample_uart_tx(top);
        
        cycle++;
        if (debug_dump_requested) {
            auto* r = top->rootp;
            const auto& pc = r->soc__DOT__gen_cluster__BRA__0__KET____DOT__gen_core__BRA__0__KET____DOT__core_u__DOT__s1_p0_fetch_pc;
            const auto& vtid = r->soc__DOT__gen_cluster__BRA__0__KET____DOT__memory_u__DOT__r_active_vtid;
            const auto& regs = r->soc__DOT__gen_cluster__BRA__0__KET____DOT__gen_core__BRA__0__KET____DOT__core_u__DOT__threaded_regfile_0__DOT__mem;
            const uint16_t sleep = r->soc__DOT__gen_cluster__BRA__0__KET____DOT__gen_core__BRA__0__KET____DOT__core_u__DOT__s1_p0_sleep;
            std::cerr << "[SIMDBG] cycle=" << cycle << " sleep=0x" << std::hex
                      << sleep
                      << " ipi_valid=0x" << unsigned(r->soc__DOT__r_ipi_resp_valid[0])
                      << " ipi_data=0x" << r->soc__DOT__r_ipi_resp_rdata[0]
                      << " ipi_vec=0x" << r->soc__DOT__r_ipi_vector[0]
                      << " timer_valid=0x" << r->soc__DOT__w_core_timer_resp_valid[0]
                      << " timer_data=0x" << r->soc__DOT__w_core_timer_resp_rdata_mux[0]
                      << " mmio_req=0x" << unsigned(r->soc__DOT__w_router_mmio_req_valid[0])
                      << " mmio_addr=0x" << r->soc__DOT__w_router_mmio_req_addr[0]
                      << std::dec << '\n';
            for (unsigned t = 0; t < 16; ++t)
                std::cerr << "[SIMDBG] t=" << t << " pc=0x" << std::hex
                          << pc[t] << " vtid=0x" << vtid[t]
                          << " ra=0x" << regs[t][0] << " sp=0x" << regs[t][1]
                          << " t0=0x" << regs[t][4] << " t2=0x" << regs[t][6]
                          << " a0=0x" << regs[t][9] << " a1=0x" << regs[t][10]
                          << " a2=0x" << regs[t][11]
                          << " a3=0x" << regs[t][12] << std::dec << '\n';
            debug_dump_requested = 0;
        }
        if (cycle % 100000 == 0) {
            refresh_framebuffer_from_sram(top);
            write_framebuffer_bmp();
        }
        if (cycle % 1024 == 0) {
            fflush(stdout);
        }
    }

    refresh_framebuffer_from_sram(top);
    write_framebuffer_bmp();

    const auto wall_end = std::chrono::steady_clock::now();
    const uint64_t run_cycles = cycle - start_cycle;
    const double wall_seconds = std::chrono::duration<double>(wall_end - wall_start).count();
    const double simulated_seconds = static_cast<double>(run_cycles) / static_cast<double>(CLOCK_FREQ_HZ);
    const double slowdown = simulated_seconds > 0.0 ? wall_seconds / simulated_seconds : 0.0;
    
    if (finish_requested) {
        VerilatedSave os;
        os.open("checkpoints/checkpoint.vls");
        os << *top;
        os << cycle;
        std::cout << "\nSaved simulation state to checkpoints/checkpoint.vls" << std::endl;
    }

    std::cout << std::fixed << std::setprecision(6)
              << "[SIM] cycles=" << run_cycles
              << " simulated_seconds=" << simulated_seconds
              << " wall_seconds=" << wall_seconds
              << " slowdown=" << slowdown << "x"
              << " clock_hz=" << CLOCK_FREQ_HZ
              << std::endl;

    if (stdin_is_tty) {
        tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
    }
    delete top;
    delete page_engine;

    return 0;
}
