    .text
    .globl branch_instructions
branch_instructions:
    bc.eq r10, r11, 1f
    bc.ne r10, r11, 1f
    bc.lt r10, r11, 1f
    bc.ge r10, r11, 1f
    bc.ltu r10, r11, 1f
    bc.geu r10, r11, 1f
    jump.rel.dir r1, 1f
1:
    auipc r10, 0
    bc.ne r10, r11, 1b
    jump.abs r0, 0(r1)
