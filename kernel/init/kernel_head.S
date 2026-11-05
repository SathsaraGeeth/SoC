#include <regs.h>
#include <soc.h>

.section .kernel_entry, "ax"
.global _kernel_start

_kernel_start:
    la              r10, _supervisor_trap_vector
    addi.i64        r10, r10, TVEC_MODE_VECTORED
    csrw            CSR_STVEC, r10

    /* thread 0 does BSS init */
    csrr            r10, CSR_THREAD_ID
    andi.64         r10, r10, THREAD_OFFSET_MASK
    bc.ne           r10, r0, 3f
    la              r2 , _kernel_stack_top
    /* Temporarily skip kernel BSS clearing.
    la              r10, _kernel_bss_start
    la              r11, _kernel_bss_end
1:
    bc.geu          r10, r11, 2f
    store.32        r0 , 0(r10)
    addi.i32        r10, r10, 4
    jump.rel.dir    r0 , 1b
    */
2:
    call            kernel_main

3:
    wfi
    jump.rel.dir    r0, 3b
