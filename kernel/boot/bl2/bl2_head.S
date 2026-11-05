#include <soc.h>
#include <regs.h>

.option push                    /* save the isa settings */
.option arch, +zmmul


.section .bl2_entry, "ax"
.global _bl2_reset

_bl2_reset:
    fence.i
    csrr            r10, CSR_THREAD_ID
    andi.64         r10, r10, THREAD_OFFSET_MASK
    bc.ne           r10, r0, _bl2_ap_entry
    la              r2,  _bl2_stack_top
    la              r10, _bl2_bss_start
    la              r11, _bl2_bss_end
/* bss init loop */
1:
    bc.geu          r10, r11, 2f
    store.32        r0,  0(r10)
    addi.i32        r10, r10, 4
    jump.rel.dir    r0,  1b

2:
    call            bl2_main

/* Non master threads polling loop bl1 -> bl2 */

_bl2_ap_entry:
    /* BL1 may transfer here with arbitrary caller-saved registers.  Derive
       the mailbox slot from the architectural RV64 thread id, not r10. */
    csrr            r10, CSR_THREAD_ID
    andi.64        r10, r10, THREAD_OFFSET_MASK
    la              r11, BL2_SMP_MAILBOX_BASE
    /* tid * 24: keep the mailbox index entirely RV64 without relying on
       the legacy assembler's missing MUL alias. */
    sli.i64         r12, r10, 4
    sli.i64         r13, r10, 3
    add.i64         r12, r12, r13
    add.i64         r11, r11, r12
1:
    load.i64        r13, ARCH_WORD_SIZE(r11)
    bc.ne           r13, r0, 2f
    wfi
    jump.rel.dir    r0, 1b
2:
    load.i64        r2, (2 * ARCH_WORD_SIZE)(r11)
    load.i64        r14, 0(r11)
    jump.abs        r0, 0(r14)

/* bl2_main should not return but if it does thread will be parked */
1:  
    wfi
    jump.rel.dir    r0, 1b

.option pop                             /* restore isa settings */
