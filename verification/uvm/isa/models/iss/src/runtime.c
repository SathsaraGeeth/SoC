/*
 * verification/uvm/isa/models/iss/src/runtime.c
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

#include "include/runtime.h"
#include "../include/iss.h"
#include "include/cpu_impl.h"
#include "include/memory_backend.h"
#include "isa_generated.h"

#include <stdlib.h>
#include <string.h>

typedef struct iss_instance {
    iss_t state;
    struct iss_instance *next;
} iss_instance_t;

typedef struct iss_runtime {
    iss_memory_backend_t *memory;
    iss_instance_t *instances;
    char *image_path;
} iss_runtime_t;

static iss_runtime_t runtime;

static iss_instance_t *find_instance(int thread_id)
{
    iss_instance_t *instance;

    for (instance = runtime.instances;
         instance != NULL;
         instance = instance->next) {
        if (iss_view_state(&instance->state, thread_id) == 0) {
            return instance;
        }
    }

    return NULL;
}

static char *copy_string(const char *source)
{
    char *copy;
    size_t length;

    if (source == NULL) {
        return NULL;
    }

    length = strlen(source) + 1u;
    copy = (char *)malloc(length);
    if (copy != NULL) {
        memcpy(copy, source, length);
    }

    return copy;
}

static int initialize_memory(const char *image_path)
{
    if (runtime.memory != NULL) {
        if (image_path == NULL || runtime.image_path == NULL) {
            return -1;
        }
        return strcmp(image_path, runtime.image_path) == 0 ? 0 : -1;
    }

    if (iss_memory_backend_create(image_path, &runtime.memory) != 0) {
        return -1;
    }

    runtime.image_path = copy_string(image_path);
    if (runtime.image_path == NULL) {
        iss_memory_backend_destroy(runtime.memory);
        runtime.memory = NULL;
        return -1;
    }

    return 0;
}

int iss_runtime_initialize(int thread_id, const char *image_path)
{
    iss_instance_t *instance;

    if (initialize_memory(image_path) != 0) {
        return -1;
    }

    instance = find_instance(thread_id);
    if (instance != NULL) {
        instance->state.isa.mem_methods->release(&instance->state.isa);
        cpu_reset(&instance->state.isa.cpu, thread_id);
        return 0;
    }

    instance = (iss_instance_t *)calloc(1, sizeof(*instance));
    if (instance == NULL) {
        return -1;
    }

    iss_init(&instance->state, thread_id);
    instance->state.memory = runtime.memory;
    instance->state.isa.memory = iss_memory_view(runtime.memory);
    instance->next = runtime.instances;
    runtime.instances = instance;

    return 0;
}

int iss_runtime_set_pc(int thread_id, uint64_t pc)
{
    iss_instance_t *instance = find_instance(thread_id);

    if (instance == NULL) {
        return -1;
    }

    cpu_write_pc(&instance->state.isa.cpu, pc);
    return 0;
}

int iss_runtime_step(int thread_id, arch_commit_trace_t *trace)
{
    iss_instance_t *instance;
    uint32_t inst;

    if (trace == NULL) {
        return -1;
    }

    memset(trace, 0, sizeof(*trace));
    instance = find_instance(thread_id);

    if (instance == NULL) {
        return -1;
    }

    inst = (uint32_t)instance->state.isa.mem_methods->read(
        &instance->state.isa,
        cpu_read_pc(&instance->state.isa.cpu),
        DMCTP_INST_WIDTH / 8u);
    return iss_exc_instr(&instance->state, inst, trace);
}

void iss_runtime_destroy(void)
{
    iss_instance_t *instance = runtime.instances;

    while (instance != NULL) {
        iss_instance_t *next = instance->next;

        free(instance);
        instance = next;
    }

    runtime.instances = NULL;
    iss_memory_backend_destroy(runtime.memory);
    runtime.memory = NULL;
    free(runtime.image_path);
    runtime.image_path = NULL;
}
