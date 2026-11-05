#include "Vfpu.h"
#include "verilated.h"
#include <algorithm>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <map>
#include <string>
#include <vector>

struct Result {
    std::string name;
    std::string kind;
    std::string lane;
    std::string op;
    std::string pattern;
    int samples = 0;
    double latency = 0.0;
    double ii = 0.0;
    int blocking = 0;
};

class Driver {
  public:
    VerilatedContext context;
    Vfpu dut;
    uint64_t cycle = 0;

    Driver() : dut(&context) {
        clear_inputs();
        dut.i_rst_n = 0;
        for (int n = 0; n < 6; ++n) tick();
        dut.i_rst_n = 1;
        tick();
    }

    void clear_inputs() {
        dut.i_clk = 0;
        dut.i_rst_n = 0;
        dut.i_l0_in_valid = 0;
        dut.i_l1_in_valid = 0;
        dut.i_l0_out_ready = 1;
        dut.i_l1_out_ready = 1;
        set_lane(0, 6, 0, 0, 0, 0);
        set_lane(1, 6, 0, 0, 0, 0);
    }

    void set_lane(int lane, int op, uint64_t thread,
                  uint64_t a, uint64_t b, uint64_t c,
                  int operand_fmt = 0, int result_fmt = 0) {
        if (lane == 0) {
            dut.i_l0_op = op;
            dut.i_l0_thrd = thread;
            dut.i_l0_a = a;
            dut.i_l0_b = b;
            dut.i_l0_c = c;
            dut.i_l0_a_fmt = operand_fmt;
            dut.i_l0_b_fmt = operand_fmt;
            dut.i_l0_c_fmt = operand_fmt;
            dut.i_l0_result_fmt = result_fmt;
        } else {
            dut.i_l1_op = op;
            dut.i_l1_thrd = thread;
            dut.i_l1_a = a;
            dut.i_l1_b = b;
            dut.i_l1_c = c;
            dut.i_l1_a_fmt = operand_fmt;
            dut.i_l1_b_fmt = operand_fmt;
            dut.i_l1_c_fmt = operand_fmt;
            dut.i_l1_result_fmt = result_fmt;
        }
    }

    void tick() {
        dut.i_clk = 0;
        dut.eval();
        dut.i_clk = 1;
        dut.eval();
        ++cycle;
        dut.i_clk = 0;
        dut.eval();
        context.timeInc(1);
    }
};

static Result stream_case(const std::string &name, int lane, int op,
                          const std::string &op_name) {
    Driver driver;
    constexpr int count = 12;
    constexpr uint64_t base_thread = 0x1000;
    std::vector<uint64_t> accepted;
    std::map<uint64_t, uint64_t> completed;
    int issued = 0;

    while (completed.size() < count && driver.cycle < 1000) {
        driver.dut.i_l0_in_valid = 0;
        driver.dut.i_l1_in_valid = 0;
        if (issued < count) {
            driver.set_lane(lane, op, base_thread + issued,
                            0x40000000, 0x40400000, 0x40800000);
            if (lane == 0)
                driver.dut.i_l0_in_valid = 1;
            else
                driver.dut.i_l1_in_valid = 1;
        }
        driver.dut.eval();
        const bool ready = lane == 0 ? driver.dut.o_l0_in_ready
                                     : driver.dut.o_l1_in_ready;
        if (issued < count && ready) {
            accepted.push_back(driver.cycle + 1);
            ++issued;
        }
        driver.tick();
        const bool valid = lane == 0 ? driver.dut.o_l0_out_valid
                                     : driver.dut.o_l1_out_valid;
        if (valid) {
            const uint64_t thread = lane == 0 ? driver.dut.o_l0_thrd
                                              : driver.dut.o_l1_thrd;
            completed[thread] = driver.cycle;
        }
    }

    double latency = 0.0;
    for (int n = 0; n < count; ++n)
        latency += completed.at(base_thread + n) - accepted[n];
    latency /= count;
    const double ii = double(accepted.back() - accepted.front()) / (count - 1);
    return {name, "pipeline", lane == 0 ? "lane 0" : "lane 1",
            op_name, "continuous independent requests", count,
            latency, ii, 0};
}

static Result iterative_case(const std::string &name, int op,
                             const std::string &op_name, bool lane0_busy,
                             int operand_fmt = 0, int result_fmt = 0,
                             uint64_t a = 0x40e00000,
                             uint64_t b = 0x40400000) {
    Driver driver;
    constexpr int count = 2;
    constexpr uint64_t base_thread = 0x2000;
    std::vector<uint64_t> accepted;
    std::map<uint64_t, uint64_t> completed;
    int issued = 0;
    int blocking = 0;
    uint64_t lane0_thread = 0x4000;

    while (completed.size() < count && driver.cycle < 4000) {
        driver.dut.i_l0_in_valid = lane0_busy;
        if (lane0_busy) {
            driver.set_lane(0, 6, lane0_thread++,
                            0x40000000, 0x40400000, 0);
        }
        driver.dut.i_l1_in_valid = issued < count;
        if (issued < count) {
            driver.set_lane(1, op, base_thread + issued,
                            a, b, 0, operand_fmt, result_fmt);
        }
        driver.dut.eval();
        const bool ready = driver.dut.o_l1_in_ready;
        if (!accepted.empty() && issued < count && !ready)
            ++blocking;
        if (issued < count && ready) {
            accepted.push_back(driver.cycle + 1);
            ++issued;
        }
        driver.tick();
        if (driver.dut.o_l1_out_valid) {
            const uint64_t thread = driver.dut.o_l1_thrd;
            if (thread >= base_thread && thread < base_thread + count)
                completed[thread] = driver.cycle;
        }
    }

    double latency = 0.0;
    for (int n = 0; n < count; ++n)
        latency += completed.at(base_thread + n) - accepted[n];
    latency /= count;
    const double ii = accepted[1] - accepted[0];
    return {name, "iterative", "lane 1", op_name,
            lane0_busy ? "lane 0 continuously busy" : "lane 0 idle",
            count, latency, ii, blocking};
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    const std::vector<Result> rows = {
        stream_case("Lane 0 ADD stream", 0, 4, "ADD"),
        stream_case("Lane 0 FMA stream", 0, 0, "FMA"),
        stream_case("Lane 1 MUL stream", 1, 6, "MUL"),
        stream_case("Lane 1 CMP stream", 1, 14, "CMP"),
        stream_case("Lane 1 conversion stream", 1, 10, "CVTF2F"),
        iterative_case("DIV with lane 0 idle", 7, "DIV", false),
        iterative_case("DIV with lane 0 busy", 7, "DIV", true),
        iterative_case("SQRT with lane 0 idle", 8, "SQRT", false),
        iterative_case("SQRT with lane 0 busy", 8, "SQRT", true),
        iterative_case("FP16 DIV", 7, "DIV", false,
                       1, 1, 0x4700, 0x4000),
        iterative_case("BF16 DIV", 7, "DIV", false,
                       5, 3, 0x40e0, 0x4000),
        iterative_case("FP8 E4M3 DIV", 7, "DIV", false,
                       2, 2, 0x3c, 0x38),
        iterative_case("FP8 E5M2 DIV", 7, "DIV", false,
                       6, 4, 0x3e, 0x3c),
        iterative_case("FP16 SQRT", 8, "SQRT", false,
                       1, 1, 0x4700, 0),
        iterative_case("BF16 SQRT", 8, "SQRT", false,
                       5, 3, 0x40e0, 0),
        iterative_case("FP8 E4M3 SQRT", 8, "SQRT", false,
                       2, 2, 0x3c, 0),
        iterative_case("FP8 E5M2 SQRT", 8, "SQRT", false,
                       6, 4, 0x3e, 0),
    };

    std::ofstream csv("fpu_perf.csv");
    csv << "case,kind,lane,op,pattern,samples,latency_cycles,ii_cycles,blocking_cycles\n";
    csv << std::fixed << std::setprecision(3);
    for (const auto &row : rows) {
        csv << row.name << ',' << row.kind << ',' << row.lane << ','
            << row.op << ',' << row.pattern << ',' << row.samples << ','
            << row.latency << ',' << row.ii << ',' << row.blocking << '\n';
    }
    return 0;
}
