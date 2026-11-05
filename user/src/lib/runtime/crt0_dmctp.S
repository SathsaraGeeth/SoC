/*
- Comments:
- 1. DMCTP uses r10/r11 for the first two ABI arguments/return values.
- 2. The kernel provides the initial user stack before entering _start.
 */

.section .text
.global _start

#include <sys/syscall.h>

_start:
    /* sp is initialized by the kernel (sys_exec). */
    call main

    /* main return value is the first syscall argument. */
    addi.i64 r11, r10, 0
    addi.i64 r10, r0, SYS_EXIT
    ECALL

1:
    jump.rel.dir r0, 1b
