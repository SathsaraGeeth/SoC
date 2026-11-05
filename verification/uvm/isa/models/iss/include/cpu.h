/*
 * verification/uvm/isa/models/iss/include/cpu.h
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
 * 1. Abstracts the CPU states
 *    1. General Purpose Registers (GPRs)
 *    2. Control and Status Registers (CSRs)
 *    3. Program Counter (PC)
 */

#ifndef DMCTP_ISS_CPU_H
#define DMCTP_ISS_CPU_H

#include <stdint.h>
#include "isa_generated.h"
#include "trace.h"

typedef struct cpu {
    uint64_t pc;
    uint64_t gprs[DMCTP_REG_COUNT];
    uint64_t csrs[DMCTP_CSR_COUNT];
} cpu_t;

typedef struct cpu_methods {
    void     (*advance_pc)(cpu_t *cpu, int64_t bytes);
    uint64_t (*read_gpr)  (const cpu_t *cpu, uint32_t address);
    void     (*write_gpr) (cpu_t *cpu, uint32_t address, uint64_t value,
                           arch_commit_trace_t *trace);
    uint64_t (*read_csr)  (const cpu_t *cpu, uint32_t address);
    void     (*write_csr) (cpu_t *cpu, uint32_t address, uint64_t value,
                           arch_commit_trace_t *trace);
} cpu_methods_t;

#endif /* DMCTP_ISS_CPU_H */
