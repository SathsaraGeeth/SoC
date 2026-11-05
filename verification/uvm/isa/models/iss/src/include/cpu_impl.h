/*
 * verification/uvm/isa/models/iss/src/include/cpu_impl.h
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
 * 1. Helpers
 */

#ifndef DMCTP_ISS_CPU_IMPL_H
#define DMCTP_ISS_CPU_IMPL_H

#include "cpu.h"

void     cpu_init      (cpu_t *cpu, int thread_id);
void     cpu_reset     (cpu_t *cpu, int thread_id);
uint64_t cpu_read_pc   (const cpu_t *cpu);
void     cpu_write_pc  (cpu_t *cpu, uint64_t value);
void     cpu_advance_pc(cpu_t *cpu, int64_t bytes);
uint64_t cpu_read_reg  (const cpu_t *cpu, uint32_t address);
void     cpu_write_reg (cpu_t *cpu, uint32_t address, uint64_t value,
                        arch_commit_trace_t *trace);
uint64_t cpu_read_csr  (const cpu_t *cpu, uint32_t address);
void     cpu_write_csr (cpu_t *cpu, uint32_t address, uint64_t value,
                        arch_commit_trace_t *trace);

extern const cpu_methods_t iss_cpu_methods;

#endif
