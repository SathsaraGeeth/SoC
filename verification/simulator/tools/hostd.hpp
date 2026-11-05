#pragma once

#include <string>
#include <vector>

namespace hostd {

    // Serves the filesystem daemon over a pseudo-terminal or standard FDs.
    // This is the core logic loop.
    void serve(const std::string& root_dir, int uart_rx_fd, int uart_tx_fd);

    // Spawns a subprocess with the given arguments, setting up a pipe for UART,
    // and invokes `serve` on the host side.
    // Also parses `--stdout-log <file>` to redirect the subprocess's stdout/stderr.
    int serve_with_subprocess(const std::string& root_dir, const std::vector<std::string>& cmd_args);

}
