#include <regs.h>
#include <soc.h>

.section .text
.global  smp_secondary_entry

smp_secondary_entry:
    csrr        r10, CSR_THREAD_ID
    andi.64     r10, r10, THREAD_OFFSET_MASK
    la          r11, _thread_stack_table
    /* _thread_stack_table contains RV64 uintptr_t entries (8-byte stride). */
    sli.i32     r12, r10, 3
    add.i32     r11, r11, r12
    load.i32    r2, 0(r11)
    call        smp_secondary_main
1:
    wfi
    jump.rel.dir r0, 1b
