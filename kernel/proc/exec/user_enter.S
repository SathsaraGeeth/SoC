/* Enter an already-prefaulted process context in U-mode. */
.section .text
.global proc_enter_user
.align 4

proc_enter_user:
    /* r10 = context_t *, r11 = top of its kernel stack */
    addi.i64 r6, r10, 0
    load.i64 r2,   8(r6)
    load.i64 r5, 248(r6)
    csrw 0x141, r5
    load.i64 r5, 256(r6)
    csrw 0x100, r5
    csrw 0x140, r11
    /* Clone entry requires its return trampoline and void * argument. */
    load.i64 r1,   0(r6)
    load.i64 r10, 72(r6)
    .word 0x10200073 /* sret */
