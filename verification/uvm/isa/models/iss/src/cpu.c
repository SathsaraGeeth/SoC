/*
 * verification/uvm/isa/models/iss/src/cpu.c
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

#include "include/cpu_impl.h"

#include <string.h>

void cpu_init(cpu_t *cpu, int thread_id) {
    cpu_reset(cpu, thread_id);
}

void cpu_reset(cpu_t *cpu, int thread_id) {
    memset(cpu, 0, sizeof(*cpu));
    cpu_write_csr(cpu, DMCTP_CSR_THREAD_ID,       (uint64_t)thread_id, NULL);
    cpu_write_csr(cpu, DMCTP_CSR_VIRTUAL_THRD_ID, (uint64_t)thread_id, NULL);
}

uint64_t cpu_read_pc(const cpu_t *cpu) {
    return cpu->pc;
}

void cpu_write_pc(cpu_t *cpu, uint64_t value) {
    cpu->pc = value;
}

void cpu_advance_pc(cpu_t *cpu, int64_t bytes) {
    cpu->pc += bytes;
}

uint64_t cpu_read_reg(const cpu_t *cpu, uint32_t address) {
    if (address >= DMCTP_REG_COUNT)              
        return 0;
    if (DMCTP_X0_HARDWIRED_ZERO && address == 0) 
        return 0;

    return cpu->gprs[address];
}

void cpu_write_reg(cpu_t *cpu, uint32_t address, uint64_t value,
                   arch_commit_trace_t *trace) {

    if (address >= DMCTP_REG_COUNT)              
        return;
    if (DMCTP_X0_HARDWIRED_ZERO && address == 0) 
        return;

    cpu->gprs[address] = value;

    if (trace != NULL) {
        trace->rf_we      = 1;
        trace->rf_pc      = cpu->pc;
        trace->rf_we_addr = address;
        trace->rf_we_data = value;
    }
}

uint64_t cpu_read_csr(const cpu_t *cpu, uint32_t address) {
    const size_t slot = dmctp_csr_slot(address);

    return slot < DMCTP_CSR_COUNT ? cpu->csrs[slot] : 0;
}

void cpu_write_csr(cpu_t *cpu, uint32_t address, uint64_t value,
                   arch_commit_trace_t *trace) {
    const size_t slot = dmctp_csr_slot(address);

    if (slot >= DMCTP_CSR_COUNT) 
        return;
    cpu->csrs[slot] = value;

    if (trace != NULL) {
        trace->csr_we      = 1;
        trace->csr_pc      = cpu->pc;
        trace->csr_we_addr = address;
        trace->csr_we_data = value;
    }
}

const cpu_methods_t iss_cpu_methods = {
    .advance_pc = cpu_advance_pc,
    .read_gpr   = cpu_read_reg,
    .write_gpr  = cpu_write_reg,
    .read_csr   = cpu_read_csr,
    .write_csr  = cpu_write_csr
};
