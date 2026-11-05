/*
 * Comments:
 * 1. Helpers
 */

#ifndef DMCTP_ISS_EXECUTION_H
#define DMCTP_ISS_EXECUTION_H

#include "iss.h"
#include "isa_generated.h"

int  iss_store_conditional  (iss_t *iss, uint64_t address,
                             uint64_t value, unsigned bytes);
int  iss_execute_instruction(iss_t *iss, uint32_t inst,
                             arch_commit_trace_t *trace);
void iss_execute_integer    (iss_t *iss, dmctp_mnemonic_t mnemonic,
                             uint32_t inst, arch_commit_trace_t *trace);
void iss_execute_load_store (iss_t *iss, dmctp_mnemonic_t mnemonic,
                             uint32_t inst, arch_commit_trace_t *trace);
void iss_execute_system     (iss_t *iss, dmctp_mnemonic_t mnemonic,
                             uint32_t inst, arch_commit_trace_t *trace);
void iss_execute_float      (iss_t *iss, dmctp_mnemonic_t mnemonic,
                             uint32_t inst, arch_commit_trace_t *trace);

#endif /* DMCTP_ISS_EXECUTION_H */
