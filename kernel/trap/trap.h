/*
 * kernel/trap/trap.h
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
 * 1. ABI between trap subsystem and the kernel
 */

#ifndef TRAP_H
#define TRAP_H

#include <stdint.h>

struct trap_frame {
    uint64_t r1;
    uint64_t r2;
    uint64_t r3;
    uint64_t r4;
    uint64_t r5;
    uint64_t r6;
    uint64_t r7;
    uint64_t r8;
    uint64_t r9;
    uint64_t r10;
    uint64_t r11;
    uint64_t r12;
    uint64_t r13;
    uint64_t r14;
    uint64_t r15;
    uint64_t r16;
    uint64_t r17;
    uint64_t r18;
    uint64_t r19;
    uint64_t r20;
    uint64_t r21;
    uint64_t r22;
    uint64_t r23;
    uint64_t r24;
    uint64_t r25;
    uint64_t r26;
    uint64_t r27;
    uint64_t r28;
    uint64_t r29;
    uint64_t r30;
    uint64_t r31;
    uint64_t sepc;
    uint64_t sstatus;
    uint64_t scause;
    uint64_t stval;
    uintptr_t restore_frame;
};

void        trap_init(void);                            /* installing trap vectors */
void        trap_dispatch(struct trap_frame *tf);       /* trap handling */
uint64_t    trap_get_cause(void);
uint64_t    trap_get_pc(struct trap_frame *tf);
const char *trap_cause_name(uint64_t cause);
const char *trap_cause_str(uint64_t cause);
void        trap_enable(void);
void        trap_disable(void);

#endif /* TRAP_H */
