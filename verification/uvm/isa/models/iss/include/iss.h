/*
 * verification/uvm/isa/models/iss/include/iss.h
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
 * 1. Abstracts the ISA
 *      i.  CPU State
 *      ii. Memory State
 *    Fully describes the ISA
 * 2. ISS simulates the ISA thus,
 *    ISS is a concrete implementation of the ISA
 */

#ifndef DMCTP_ISS_H
#define DMCTP_ISS_H

#include <stdint.h>
#include "isa.h"
#include "trace.h"

typedef struct iss_memory_backend iss_memory_backend_t;

typedef struct iss {
    isa_t                isa;
    iss_memory_backend_t *memory;
    uint32_t             owner;
} iss_t;

void     iss_init      (iss_t *iss, int thread_id);
int      iss_exc_instr (iss_t *iss, uint32_t inst,
                        arch_commit_trace_t *trace);
int      iss_view_state(const iss_t *iss, int thread_id);

#endif /* DMCTP_ISS_H */
