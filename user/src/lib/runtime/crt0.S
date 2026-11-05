.section .text
.global _start

#include <sys/syscall.h>

_start:
    # sp is initialized by the kernel (sys_exec)
    jal main
    
    # Exit with the return value of main (exit status in a1, syscall num in a0)
    mv a1, a0
    li a0, SYS_EXIT
    ecall
    
1:
    j 1b
