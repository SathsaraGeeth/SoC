/*
 * Comments:
 * 1. DPIC boundary
 */

#include "src/include/runtime.h"

int iss_dpi_init(int thread_id, const char *image_path) {
    return iss_runtime_initialize(thread_id, image_path);
}

int iss_set_pc(int thread_id, uint64_t pc) {
    return iss_runtime_set_pc(thread_id, pc);
}

void iss_finish(void) {
    iss_runtime_destroy();
}

void iss_step_raw(int thread_id,
                  uint64_t *commit_pc, uint8_t *commit_valid,
                  uint64_t *rf_pc, uint8_t *rf_we,
                  uint32_t *rf_we_addr, uint64_t *rf_we_data,
                  uint64_t *csr_pc, uint8_t *csr_we,
                  uint32_t *csr_we_addr, uint64_t *csr_we_data,
                  uint64_t *mem_pc, uint8_t *mem_req_we,
                  uint64_t *mem_req_addr, uint64_t *mem_req_wdata,
                  uint64_t *mem_req_wmask) {

    arch_commit_trace_t trace = {0};

    (void)iss_runtime_step(thread_id, &trace);

    *commit_pc     = trace.commit_pc;
    *commit_valid  = trace.commit_valid;
    *rf_pc         = trace.rf_pc;
    *rf_we         = trace.rf_we;
    *rf_we_addr    = trace.rf_we_addr;
    *rf_we_data    = trace.rf_we_data;
    *csr_pc        = trace.csr_pc;
    *csr_we        = trace.csr_we;
    *csr_we_addr   = trace.csr_we_addr;
    *csr_we_data   = trace.csr_we_data;
    *mem_pc        = trace.mem_pc;
    *mem_req_we    = trace.mem_req_we;
    *mem_req_addr  = trace.mem_req_addr;
    *mem_req_wdata = trace.mem_req_wdata;
    *mem_req_wmask = trace.mem_req_wmask;
}
