/*
 * verification/uvm/isa/models/iss/src/decode.c
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


#include "../include/iss.h"
#include "include/cpu_impl.h"
#include "include/execution.h"

#include <stdio.h>

int iss_execute_instruction(iss_t *iss, uint32_t inst,
                            arch_commit_trace_t *trace) {

    cpu_t                          *cpu  = &iss->isa.cpu;
    const dmctp_instruction_desc_t *desc = dmctp_decode(inst);

    if (trace != NULL) {
        trace->commit_pc    = cpu_read_pc(cpu);
        trace->commit_valid = desc != NULL;
    }
    if (desc == NULL) {
        fprintf(stderr, "ISS illegal instruction 0x%08x at PC 0x%llx\n",
                inst, (unsigned long long)cpu_read_pc(cpu));
        return -1;
    }
    
    switch (desc->group) {
        case DMCTP_GROUP_LOAD_STORE:
        case DMCTP_GROUP_FENCE:
                iss_execute_load_store(iss, desc->mnemonic, inst, trace);
                break;
        case DMCTP_GROUP_BRANCH:
        case DMCTP_GROUP_INTEGER_ALU:
                iss_execute_integer(iss, desc->mnemonic, inst, trace);
                break;
        case DMCTP_GROUP_SYSTEM:
                iss_execute_system(iss, desc->mnemonic, inst, trace);
                break;
        default:
                iss_execute_float(iss, desc->mnemonic, inst, trace);
                break;
    }
    return 0;
}
