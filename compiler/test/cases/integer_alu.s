    .text
    .globl integer_alu_instructions
integer_alu_instructions:
    add.i64 r10, r11, r12
    addi.i64 r10, r11, 17
    sub.i64 r10, r11, r12
    mul.64.lo r10, r11, r12
    mul.iu64.hi r10, r11, r12
    sl.i64 r10, r11, r12
    sli.i64 r10, r11, 7
    sr.u64 r10, r11, r12
    sr.i64 r10, r11, r12
    sri.u64 r10, r11, 7
    sri.i64 r10, r11, 7
    and.64 r10, r11, r12
    andi.64 r10, r11, 31
    or.64 r10, r11, r12
    ori.64 r10, r11, 31
    xor.64 r10, r11, r12
    xori.64 r10, r11, 31
    slt.i64 r10, r11, r12
    slt.u64 r10, r11, r12
    slti.i64 r10, r11, 31
    slti.u64 r10, r11, 31
    jump.abs r0, 0(r1)
