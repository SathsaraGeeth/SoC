/* 
 * kernel/boot/bl2/trap/trap.S
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


#include <soc.h>
#include <regs.h>

#define TRAP_FRAME_SIZE (16 * ARCH_WORD_SIZE)

.section    .text
.global     _trap_entry
.align      ARCH_WORD_SIZE

/* Make a trap frame */
_trap_entry:
    /* set sp */
    addi.i32 r2, r2, -TRAP_FRAME_SIZE
    /* Save saved regs */
    store.32 r1,  0(r2)
    store.32 r5,  4(r2)
    store.32 r6,  8(r2)
    store.32 r7,  12(r2)
    store.32 r10, 16(r2)
    store.32 r11, 20(r2)
    store.32 r12, 24(r2)
    store.32 r13, 28(r2)
    store.32 r14, 32(r2)
    store.32 r15, 36(r2)
    store.32 r16, 40(r2)
    store.32 r17, 44(r2)
    store.32 r28, 48(r2)
    store.32 r29, 52(r2)
    store.32 r30, 56(r2)
    store.32 r31, 60(r2)
    /* call trap handler passing the sp */
    addi.i32 r10, r2, 0
    call trap_handler
    /* restore saved regs */
    load.i32 r1,  0(r2)
    load.i32 r5,  4(r2)
    load.i32 r6,  8(r2)
    load.i32 r7,  12(r2)
    load.i32 r10, 16(r2)
    load.i32 r11, 20(r2)
    load.i32 r12, 24(r2)
    load.i32 r13, 28(r2)
    load.i32 r14, 32(r2)
    load.i32 r15, 36(r2)
    load.i32 r16, 40(r2)
    load.i32 r17, 44(r2)
    load.i32 r28, 48(r2)
    load.i32 r29, 52(r2)
    load.i32 r30, 56(r2)
    load.i32 r31, 60(r2)
    /* restore reg - sp */
    addi.i32 r2, r2, TRAP_FRAME_SIZE
    mret
