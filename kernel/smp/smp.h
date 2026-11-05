/* 
 * kernel/smp/smp.h
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

#ifndef SMP_H
#define SMP_H

#include <stdint.h>
#include <stddef.h>
#include <soc.h>
#include <regs.h>

typedef enum {
    THREAD_OFFLINE = 0,
    THREAD_BOOTING,
    THREAD_ONLINE,
    THREAD_IDLE
} thread_state_t;

typedef struct {
    uint32_t        tid;
    thread_state_t  state;
    uintptr_t       stack_top;
} thread_t;

/* Global state */
extern thread_t threads[THREADS_IN_CLUSTER];
extern volatile uint32_t num_threads_online;


/* api */
void smp_init(void);
void smp_secondary_main(void);



static inline uint32_t smp_get_tid(void) {
    return THREAD_OFFSET(csr_read(CSR_THREAD_ID));
}

static inline int smp_is_enabled(void) {
    return num_threads_online > 1;
}

static inline uint32_t smp_online_count(void) {
    return num_threads_online;
}

#endif /* SMP_H */
