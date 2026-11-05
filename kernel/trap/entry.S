/*
 * Comments:
 * 1. This is the first thing runs after trap is triggered. (the hw supports vectored traps)
 * 2. This do:
 *  i.   recieve control (cpu has saved mepc, mcause) and loaded the pc with mtvec (point to here)
 *  ii.  switch stack if needed (if from user mode switch to kernel stack)
 *  iii. save registers (trap frame (tf)) & csrs
 *  iv.  call the trap handler
 *  v.   after trap handler returns, restore registers & csrs
 */

#include <regs.h>

#define TRAP_FRAME_SIZE 288

.section .text
.global _supervisor_trap_vector
.global _supervisor_trap_entry

.align 6
_supervisor_trap_vector:
    jump.rel.dir r0, _supervisor_trap_entry     /*  0: synchronous exceptions */
    jump.rel.dir r0, _supervisor_trap_entry     /*  1: supervisor software */
    jump.rel.dir r0, _supervisor_trap_entry     /*  2: virtual supervisor software */
    jump.rel.dir r0, _supervisor_trap_entry     /*  3: machine software */
    jump.rel.dir r0, _supervisor_trap_entry     /*  4: reserved */
    jump.rel.dir r0, _supervisor_trap_entry     /*  5: supervisor timer */
    jump.rel.dir r0, _supervisor_trap_entry     /*  6: virtual supervisor timer */
    jump.rel.dir r0, _supervisor_trap_entry     /*  7: machine timer */
    jump.rel.dir r0, _supervisor_trap_entry     /*  8: reserved */
    jump.rel.dir r0, _supervisor_trap_entry     /*  9: supervisor external */
    jump.rel.dir r0, _supervisor_trap_entry     /* 10: virtual supervisor external */
    jump.rel.dir r0, _supervisor_trap_entry     /* 11: machine external */
    jump.rel.dir r0, _supervisor_trap_entry     /* 12: supervisor guest external */
    jump.rel.dir r0, _supervisor_trap_entry     /* 13: counter overflow */

.align 4
_supervisor_trap_entry:
    /*
     * r2 is sp
     * in user mode sscratch holds the kernel stack pointer
     * in kernel mode sscratch holds 0
     */
    csrrw           r2, CSR_SSCRATCH, r2
    bc.ne           r2, r0, .Lfrom_user

    /*
     * from_kernel...
     */
    csrrw           r2, CSR_SSCRATCH, r2
    addi.i64        r2, r2, -TRAP_FRAME_SIZE
    store.64        r5, 32(r2)
    addi.i64        r5, r2, TRAP_FRAME_SIZE
    store.64        r5, 8(r2)
    jump.rel.dir    r0, .Lsave_context

.Lfrom_user:
    addi.i64        r2, r2, -TRAP_FRAME_SIZE
    store.64        r5, 32(r2)
    csrr            r5, CSR_SSCRATCH
    store.64        r5, 8(r2)
    csrw            CSR_SSCRATCH, r0        /* traps handled in kernel mode */

.Lsave_context:
    /* save registers */
    store.64        r1,   0(r2)
    store.64        r3,  16(r2)
    store.64        r4,  24(r2)
    store.64        r6,  40(r2)
    store.64        r7,  48(r2)
    store.64        r8,  56(r2)
    store.64        r9,  64(r2)
    store.64        r10, 72(r2)
    store.64        r11, 80(r2)
    store.64        r12, 88(r2)
    store.64        r13, 96(r2)
    store.64        r14, 104(r2)
    store.64        r15, 112(r2)
    store.64        r16, 120(r2)
    store.64        r17, 128(r2)
    store.64        r18, 136(r2)
    store.64        r19, 144(r2)
    store.64        r20, 152(r2)
    store.64        r21, 160(r2)
    store.64        r22, 168(r2)
    store.64        r23, 176(r2)
    store.64        r24, 184(r2)
    store.64        r25, 192(r2)
    store.64        r26, 200(r2)
    store.64        r27, 208(r2)
    store.64        r28, 216(r2)
    store.64        r29, 224(r2)
    store.64        r30, 232(r2)
    store.64        r31, 240(r2)

    /* save csrs */
    csrr            r5, CSR_SEPC
    store.64        r5, 248(r2)
    csrr            r5, CSR_SSTATUS
    store.64        r5, 256(r2)
    csrr            r5, CSR_SCAUSE
    store.64        r5, 264(r2)
    csrr            r5, CSR_STVAL
    store.64        r5, 272(r2)
    addi.i64        r5, r2, 0
    store.64        r5, 280(r2)

    /* void trap_dispatch(struct trap_frame *ctx); r2 = trap-frame ptr */
    addi.i64        r10, r2, 0
    call            trap_dispatch

    /* The scheduler selects the frame restored by the assembly layer. */
    load.i64        r2, 280(r2)

    /*
     * selected task's kernel stack in sscratch, it may or may switched
     */
    load.i64        r5, 256(r2)
    sri.u64         r5, r5, 8
    andi.64        r5, r5, 1
    bc.ne           r5, r0, .Lrestore_context
    csrr            r5, CSR_SSCRATCH
    bc.ne           r5, r0, .Lrestore_context
    addi.i64        r5, r2, TRAP_FRAME_SIZE
    csrw            CSR_SSCRATCH, r5

.Lrestore_context:
    load.i64        r5, 248(r2)
    csrw            CSR_SEPC, r5
    load.i64        r5, 256(r2)
    csrw            CSR_SSTATUS, r5

    load.i64        r1,   0(r2)
    load.i64        r3,  16(r2)
    load.i64        r4,  24(r2)
    load.i64        r5,  32(r2)
    load.i64        r6,  40(r2)
    load.i64        r7,  48(r2)
    load.i64        r8,  56(r2)
    load.i64        r9,  64(r2)
    load.i64        r10, 72(r2)
    load.i64        r11, 80(r2)
    load.i64        r12, 88(r2)
    load.i64        r13, 96(r2)
    load.i64        r14, 104(r2)
    load.i64        r15, 112(r2)
    load.i64        r16, 120(r2)
    load.i64        r17, 128(r2)
    load.i64        r18, 136(r2)
    load.i64        r19, 144(r2)
    load.i64        r20, 152(r2)
    load.i64        r21, 160(r2)
    load.i64        r22, 168(r2)
    load.i64        r23, 176(r2)
    load.i64        r24, 184(r2)
    load.i64        r25, 192(r2)
    load.i64        r26, 200(r2)
    load.i64        r27, 208(r2)
    load.i64        r28, 216(r2)
    load.i64        r29, 224(r2)
    load.i64        r30, 232(r2)
    load.i64        r31, 240(r2)
    load.i64        r2,   8(r2)
    sret
