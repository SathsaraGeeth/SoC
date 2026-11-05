/*
 * verification/uvm/isa/models/iss/src/iss.c
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
#include "include/memory_backend.h"

#include <string.h>

static iss_t *iss_from_isa(isa_t *isa) {
    return (iss_t *)isa;
}

static uint64_t read_memory(isa_t *isa, uint64_t address, unsigned bytes) {
    iss_t *iss = iss_from_isa(isa);

    return iss_memory_read(iss->memory, address, bytes);
}

static void write_memory(isa_t *isa, uint64_t address,
                         uint64_t value, unsigned bytes) {
    iss_t *iss = iss_from_isa(isa);

    iss_memory_write(iss->memory, address, value, bytes);
}

static void reserve_memory(isa_t *isa, uint64_t address) {
    iss_t *iss = iss_from_isa(isa);

    iss_memory_reserve(iss->memory, iss->owner, address);
}

static void release_memory(isa_t *isa) {
    iss_t *iss = iss_from_isa(isa);

    if (iss->memory != NULL) {
        iss_memory_release(iss->memory, iss->owner);
    }
}

static const mem_methods_t iss_mem_methods = {
    .read    = read_memory,
    .write   = write_memory,
    .reserve = reserve_memory,
    .release = release_memory
};

int iss_store_conditional(iss_t *iss, uint64_t address,
                          uint64_t value, unsigned bytes) {

    return iss_memory_store_conditional
        (iss->memory, iss->owner, address, value, bytes);
}

int iss_exc_instr(iss_t *iss, uint32_t inst, arch_commit_trace_t *trace) {
    return iss_execute_instruction(iss, inst, trace);
}

void iss_init(iss_t *iss, int thread_id) {

    memset(iss, 0, sizeof(*iss));
    cpu_init(&iss->isa.cpu, thread_id);
    iss->isa.cpu_methods = &iss_cpu_methods;
    iss->isa.mem_methods = &iss_mem_methods;
    iss->owner = (uint32_t)thread_id;
}

int iss_view_state(const iss_t *iss, int thread_id) {
    if (iss == NULL)
        return -1;

    return cpu_read_csr(&iss->isa.cpu, DMCTP_CSR_THREAD_ID)
                == (uint64_t)thread_id ? 0 : -1;
}
