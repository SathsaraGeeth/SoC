    .text
    .globl system_instructions
system_instructions:
    csrrw r10, 768, r11
    csrrwi r10, 768, 7
    csrrs r12, 833, r0
    csrrsi r12, 833, 7
    csrrc r13, 834, r14
    csrrci r13, 834, 7
    fence.i
    fence.d.ls.ls
    fence.d.l.l
    fence.d.s.s
    fence.d.l.s
    fence.d.s.l
    ecall
    sret
    mret
    wfi
