/*
 * verification/uvm/isa/models/iss/src/float.c
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
 * 1. TODO: implement this
 */

#include "../include/iss.h"
#include "include/cpu_impl.h"
#include "include/execution.h"

void iss_execute_float(iss_t *iss, dmctp_mnemonic_t mnemonic,
                       uint32_t inst, arch_commit_trace_t *trace)
{
    cpu_t *cpu = &iss->isa.cpu;
    (void)mnemonic;
    (void)inst;
    (void)trace;
    cpu_advance_pc(cpu, DMCTP_INST_WIDTH / 8u);
}
