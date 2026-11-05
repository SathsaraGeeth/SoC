/*
 * Comments:
 * 1. For each memory region a mailbox
 * 2. Mailbox structure:
 *      - entry function pointer [0]
 *      - release flag           [0]
 *      - stack                  [0]
 *      - entry function pointer [1]
 *      - release flag           [1]
 *      - stack                  [1]
 *                  .
 *                  .
 *                  .
 *      - entry function pointer [N]
 *      - release flag           [N]
 *      - stack                  [N]
 * 3. We don't need a slot for master thread but kept for symmetry
 * 4. Following assembly set entry function of each thread and set release flag
 */

#include <soc.h>

.option push                    /* save the isa settings */
.option arch, +zmmul

/*
 * void smp_set_entry(uint32_t tid, void (*entry)(void))
 *
 * r10 = tid
 * r11 = entry
 */
.global smp_set_entry
smp_set_entry:
    la              r12, BL2_SMP_MAILBOX_BASE
    addi.i32        r13, r0,  (3*ARCH_WORD_SIZE)
    mul.i32.lo      r13, r10, r13
    add.i32         r12, r12, r13
    store.32        r11, 0(r12)
    jump.abs        r0,  0(r1)

/*
 * void smp_set_release(uint32_t tid)
 *
 * r10 = tid
 */
.global smp_set_release
smp_set_release:
    la              r11, BL2_SMP_MAILBOX_BASE
    addi.i32        r13, r0,  (3*ARCH_WORD_SIZE)
    mul.i32.lo      r13, r10, r13
    add.i32         r11, r11, r13
    fence iorw, rw                                          /* fence.d.ls.ls */
    addi.i32        r12, r0, 1
    store.32        r12, ARCH_WORD_SIZE(r11)
    jump.abs        r0,  0(r1)

/*
 * void smp_set_stack(uint32_t tid, uint32_t stack)
 *
 * r10 = tid
 * r11 = stack pointer
 */
.global smp_set_stack
smp_set_stack:
    la              r12, BL2_SMP_MAILBOX_BASE
    addi.i32        r13, r0,  (3*ARCH_WORD_SIZE)
    mul.i32.lo      r13, r10, r13
    add.i32         r12, r12, r13
    store.32        r11, (2 * ARCH_WORD_SIZE)(r12)
    jump.abs        r0,  0(r1)

.option pop                             /* restore isa settings */
