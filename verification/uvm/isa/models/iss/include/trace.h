/* 
 * verification/uvm/isa/models/iss/include/trace.h
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

/*
 * Comments:
 * 1. Abstracts the architectural commit
 *    - as change of the state of ISA (i.e. CPU and Memory)
 */

#ifndef DMCTP_ISS_TRACE_H
#define DMCTP_ISS_TRACE_H

#include <stdint.h>

typedef struct arch_commit_trace {
    uint64_t commit_pc;
    uint8_t  commit_valid;
    uint64_t rf_pc;
    uint8_t  rf_we;
    uint32_t rf_we_addr;
    uint64_t rf_we_data;
    uint64_t csr_pc;
    uint8_t  csr_we;
    uint32_t csr_we_addr;
    uint64_t csr_we_data;
    uint64_t mem_pc;
    uint8_t  mem_req_we;
    uint64_t mem_req_addr;
    uint64_t mem_req_wdata;
    uint64_t mem_req_wmask;
} arch_commit_trace_t;

#endif /* DMCTP_ISS_TRACE_H */
