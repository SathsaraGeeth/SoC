/*
 * Comments:
 * 1. Helpers
 */

#ifndef DMCTP_ISS_RUNTIME_H
#define DMCTP_ISS_RUNTIME_H

#include <stdint.h>
#include "trace.h"

int  iss_runtime_initialize(int thread_id, const char *image_path);
int  iss_runtime_set_pc    (int thread_id, uint64_t pc);
int  iss_runtime_step      (int thread_id, arch_commit_trace_t *trace);
void iss_runtime_destroy   (void);

#endif /* DMCTP_ISS_RUNTIME_H */
