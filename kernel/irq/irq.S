#include <regs.h>

.section .text

.global irq_disable
.global irq_enable
.global irq_save
.global irq_restore


irq_disable:
    addi.i64    r5, r0, 2
    csrrc       r0, CSR_SSTATUS, r5
    jump.abs    r0, 0(r1)

irq_enable:
    addi.i64    r5, r0, 2
    csrrs       r0, CSR_SSTATUS, r5
    jump.abs    r0, 0(r1)

irq_save:
    addi.i64    r5, r0, 2
    csrrc       r10, CSR_SSTATUS, r5
    addi.i64    r10, r10, 2
    jump.abs    r10, 0(r1)

irq_restore:
    bc.eq        r10, r0, 1f
    addi.i64     r5, r0, 2
    csrrs        r0, CSR_SSTATUS, r5
1:
    jump.abs    r0, 0(r1)
