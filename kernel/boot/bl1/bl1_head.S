/* 
 * boot/bl1/head.S - BL1 ROM entry point
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
 * 1. REGs: 0 (r0), ra (r1), sp (r2)
 * 2. Why THREADS_IN_CLUSTER? becuse #clusters = #memory region; so every one and only one get stack.
 * 3. Master is the thread_id&mask = 0 in one cluster for a region. see soc.h for more details.
 */

#include <soc.h>
#include <regs.h>

.option push
.option arch, +zmmul

.section         .boot_rom, "ax"
.global          _bl1_start

/* park every other thread except the master */
_bl1_start:
    la           r10, _machine_trap_vector
    addi.i64     r10, r10, TVEC_MODE_VECTORED
    csrw         CSR_MTVEC, r10

    /* 0 initialize the gprs */
    addi.i64     r1,  r0, 0
    addi.i64     r3,  r0, 0
    addi.i64     r4,  r0, 0
    addi.i64     r5,  r0, 0
    addi.i64     r6,  r0, 0
    addi.i64     r7,  r0, 0
    addi.i64     r8,  r0, 0
    addi.i64     r9,  r0, 0
    addi.i64     r11, r0, 0
    addi.i64     r12, r0, 0
    addi.i64     r13, r0, 0
    addi.i64     r14, r0, 0
    addi.i64     r15, r0, 0
    addi.i64     r16, r0, 0
    addi.i64     r17, r0, 0
    addi.i64     r18, r0, 0
    addi.i64     r19, r0, 0
    addi.i64     r20, r0, 0
    addi.i64     r21, r0, 0
    addi.i64     r22, r0, 0
    addi.i64     r23, r0, 0
    addi.i64     r24, r0, 0
    addi.i64     r25, r0, 0
    addi.i64     r26, r0, 0
    addi.i64     r27, r0, 0
    addi.i64     r28, r0, 0
    addi.i64     r29, r0, 0
    addi.i64     r30, r0, 0
    addi.i64     r31, r0, 0

    csrr         r10, CSR_THREAD_ID    
    andi.64     r11, r10, THREAD_OFFSET_MASK
    
    la           r2,  _stack_top
    sli.i64      r12, r11, BL1_THREAD_STACK_SHIFT
    sub.i64      r2,  r2, r12
    
    bc.ne        r11, r0, _wait_for_bss

    la           r12, _bss_start
    la           r13, _bss_end

/* bss 0 init loop */
1:
    bc.geu       r12, r13, 2f
    store.32     r0, 0(r12)
    addi.i64     r12, r12, 4
    jump.rel.dir r0, 1b

2:
    la           r12, bss_cleared_flag
    addi.i64     r13, r0, 1
    store.32     r13, 0(r12)
    jump.rel.dir r0, _call_main

_wait_for_bss:
    la           r12, bss_cleared_flag
1:
    load.i32     r13, 0(r12)
    bc.ne        r13, r0, _call_main
    wfi
    jump.rel.dir r0, 1b

_call_main:
    call         bl1_main

_ap_park:
    la           r10, ap_release_flag

/* sleep loop for threads other than master */
1:
    load.i32     r11, 0(r10)
    bc.ne        r11, r0, 2f
    wfi
    jump.rel.dir r0, 1b

/* setup stack for threads other than master */
2:
    la           r2, ap_stacks
    csrr         r10, CSR_THREAD_ID
    andi.64     r10, r10, THREAD_OFFSET_MASK
    sli.i64      r10, r10, 3
    add.i64      r2, r2, r10
    load.i64     r2, 0(r2)
    la           r10, ap_entry_fn
    load.i64     r11, 0(r10)
    jump.abs     r0, 0(r11)

/*
 * Permanent M-mode vector table. Slot zero handles synchronous exceptions;
 * interrupt cause N enters at slot N.
 */
.align 6
.global _machine_trap_vector
_machine_trap_vector:
    jump.rel.dir r0, _machine_trap_entry /*  0: exceptions */
    jump.rel.dir r0, _machine_trap_entry /*  1: supervisor software */
    jump.rel.dir r0, _machine_trap_entry /*  2: virtual supervisor software */
    jump.rel.dir r0, _machine_trap_entry /*  3: machine software */
    jump.rel.dir r0, _machine_trap_entry /*  4: reserved */
    jump.rel.dir r0, _machine_trap_entry /*  5: supervisor timer */
    jump.rel.dir r0, _machine_trap_entry /*  6: virtual supervisor timer */
    jump.rel.dir r0, _machine_trap_entry /*  7: machine timer */
    jump.rel.dir r0, _machine_trap_entry /*  8: reserved */
    jump.rel.dir r0, _machine_trap_entry /*  9: supervisor external */
    jump.rel.dir r0, _machine_trap_entry /* 10: virtual supervisor external */
    jump.rel.dir r0, _machine_trap_entry /* 11: machine external */
    jump.rel.dir r0, _machine_trap_entry /* 12: supervisor guest external */
    jump.rel.dir r0, _machine_trap_entry /* 13: counter overflow */

.align 4
.global _machine_trap_entry
_machine_trap_entry:
    wfi
    jump.rel.dir r0, _machine_trap_entry


.section          .data
.global           ap_entry_fn
.global           ap_release_flag
.global           ap_stacks
.global           bss_cleared_flag
ap_entry_fn:      .dword 0
ap_release_flag:  .word 0
bss_cleared_flag: .word 0
ap_stacks:        .fill THREADS_IN_CLUSTER, 8, 0

.option pop
