#include "Vsys_core.h"
#include "Vsys_core___024root.h"
#include "svdpi.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <cstdint>
#include <deque>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

extern "C" void get_sys_core_perf_vec(const svBitVecVal *value);

static uint64_t word(const svBitVecVal *v, int n) {
    return uint64_t(v[n]) | (uint64_t(v[n + 1]) << 32);
}

struct MemoryModel {
    struct Pending { int due = -1; uint64_t data = 0; };
    std::array<std::deque<Pending>, 3> read{};
    uint32_t lfsr = 0x1aceu;

    int latency() {
        lfsr = (lfsr >> 1) ^ (uint32_t(-(lfsr & 1u)) & 0xd0000001u);
        return 4 + (lfsr & 7u) % 7; // Deterministic 4..10-cycle read latency.
    }
    void drive(Vsys_core &dut, uint64_t cycle) {
        for (int p = 0; p < 3; ++p) {
            dut.i_req_ready[p] = 1;
            dut.i_resp_valid[p] = !read[p].empty() && uint64_t(read[p].front().due) <= cycle;
            dut.i_resp_rdata[p] = read[p].empty() ? 0 : read[p].front().data;
            dut.i_resp_thrd[p] = 0;
            dut.i_resp_sc_succ[p] = 1;
        }
    }
    void accept(Vsys_core &dut, uint64_t cycle) {
        for (int p = 0; p < 3; ++p) {
            if (dut.i_resp_valid[p] && dut.o_resp_ready[p]) read[p].pop_front();
            if (dut.o_req_valid[p] && dut.i_req_ready[p] && !dut.o_req_we[p])
                read[p].push_back({int(cycle + latency()), dut.o_req_addr[p] ^ 0x5a5a123498764321ull});
        }
    }
};

class Driver {
  public:
    Vsys_core dut;
    MemoryModel memory;
    uint64_t cycle = 0;
    bool collect = false;
    std::array<uint8_t, 5> fifo_peak{};
    std::ofstream trace;

    Driver() {
        dut.i_mmio_req_valid = 0; dut.i_mmio_req_addr = 0; dut.i_mmio_req_wdata = 0;
        dut.i_mmio_req_wmask = 0; dut.i_mmio_resp_ready = 1; dut.i_host_thrd = 0; dut.i_rst_n = 0;
        memory.drive(dut, cycle); dut.eval();
        for (int n = 0; n < 6; ++n) tick();
        dut.i_rst_n = 1; tick();
    }
    void tick() {
        memory.drive(dut, cycle);
        dut.i_clk = 0; dut.eval();
        dut.i_clk = 1; dut.eval();
        memory.accept(dut, cycle++);
        if (collect) {
            svBitVecVal perf[20] = {};
            get_sys_core_perf_vec(perf);
            const uint64_t levels = word(perf, 0);
            const int shift[] = {0, 8, 16, 24, 48};
            for (int n = 0; n < 5; ++n) fifo_peak[n] = std::max(fifo_peak[n], uint8_t(levels >> shift[n]));
            if (trace.is_open() && cycle % 10 == 0) {
                trace << cycle << ',' << unsigned((levels >> 0) & 0xff) << ',' << unsigned((levels >> 8) & 0xff) << ','
                      << unsigned((levels >> 16) & 0xff) << ',' << unsigned((levels >> 24) & 0xff) << ','
                      << unsigned((levels >> 48) & 0xff) << '\n';
            }
        }
        Verilated::timeInc(1);
    }
    void command(const std::array<uint64_t, 4> &words) {
        for (uint64_t data : words) {
            while (!dut.o_mmio_req_ready) tick();
            dut.i_mmio_req_valid = 1; dut.i_mmio_req_addr = 0x08; dut.i_mmio_req_wdata = data; dut.i_mmio_req_wmask = 0xff;
            tick();
            dut.i_mmio_req_valid = 0; dut.i_mmio_req_wmask = 0;
        }
    }
    void run(uint64_t cycles) { while (cycles--) tick(); }
    void run_until_complete(uint64_t limit) {
        uint64_t completed_at = 0;
        while (cycle < limit) {
            tick();
            svBitVecVal perf[20] = {};
            get_sys_core_perf_vec(perf);
            if (!completed_at && word(perf, 16)) completed_at = cycle;
            if (completed_at && cycle >= completed_at + 320) return;
        }
    }
    uint64_t packed_fifo_peak() const {
        const int shift[] = {0, 8, 16, 24, 48}; uint64_t result = 0;
        for (int n = 0; n < 5; ++n) result |= uint64_t(fifo_peak[n]) << shift[n];
        return result;
    }
};

static std::string plusarg(int argc, char **argv, const char *key, const char *fallback) {
    const std::string prefix = std::string("+") + key + "=";
    for (int i = 1; i < argc; ++i) if (std::string(argv[i]).rfind(prefix, 0) == 0) return std::string(argv[i]).substr(prefix.size());
    return fallback;
}

static std::vector<std::array<uint64_t, 4>> load_commands(const std::string &file) {
    std::ifstream input(file); std::string text; std::vector<uint64_t> words;
    while (input >> text) words.push_back(std::stoull(text, nullptr, 16));
    const size_t count = words.empty() ? 0 : words[0];
    std::vector<std::array<uint64_t, 4>> commands(count);
    for (size_t n = 0; n < count; ++n) for (int w = 0; w < 4; ++w) commands[n][w] = words[1 + n * 4 + w];
    return commands;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Driver driver;
    svSetScope(svGetScopeFromName("TOP.sys_core"));
    driver.collect = true;
    driver.trace.open("fifo_trace.csv");
    driver.trace << "cycle,command,addr_a,addr_b,addr_d,output\n";
    for (const auto &command : load_commands(plusarg(argc, argv, "WORKLOAD_MEM", "workloads.mem")))
        driver.command(command);
    driver.run_until_complete(driver.cycle + std::stoull(plusarg(argc, argv, "SAMPLE_CYCLES", "30000")));
    svBitVecVal perf[20] = {};
    get_sys_core_perf_vec(perf);
    std::ofstream csv("sys_core_perf.csv");
    csv << "workload,accel_cycles,mac_cycles,stall_cycles,a_loaded,b_loaded,d_stored,dense_macs,native_macs,fifo_levels\n";
    csv << "0," << word(perf, 16) << ',' << word(perf, 14) << ',' << word(perf, 12) << ',' << word(perf, 10) << ','
        << word(perf, 8) << ',' << word(perf, 6) << ',' << word(perf, 4) << ',' << word(perf, 2) << ",0x" << std::hex << driver.packed_fifo_peak() << '\n';
    return 0;
}
