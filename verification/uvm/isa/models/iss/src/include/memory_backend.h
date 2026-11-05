/*
 * Comments:
 * 1. Helpers
 */

#ifndef DMCTP_ISS_MEMORY_BACKEND_H
#define DMCTP_ISS_MEMORY_BACKEND_H

#include "memory.h"

typedef struct iss_memory_backend iss_memory_backend_t;

int      iss_memory_backend_create   (const char *image_path,
                                      iss_memory_backend_t **backend);
void     iss_memory_backend_destroy  (iss_memory_backend_t *backend);
mem_t   *iss_memory_view             (iss_memory_backend_t *backend);
uint64_t iss_memory_read             (iss_memory_backend_t *backend,
                                      uint64_t address, unsigned bytes);
void     iss_memory_write            (iss_memory_backend_t *backend, uint64_t address, 
                                      uint64_t value, unsigned bytes);
void     iss_memory_reserve          (iss_memory_backend_t *backend, uint32_t owner, 
                                      uint64_t address);
int      iss_memory_store_conditional(iss_memory_backend_t *backend, uint32_t owner,
                                      uint64_t address, uint64_t value, unsigned bytes);
void     iss_memory_release          (iss_memory_backend_t *backend, uint32_t owner);

#endif /* DMCTP_ISS_MEMORY_BACKEND_H */
