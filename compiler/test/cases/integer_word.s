    .text
    .globl integer_word_instructions
integer_word_instructions:
    add.i32 r10, r11, r12
    addi.i32 r10, r11, 17
    sub.i32 r10, r11, r12
    mul.i32.lo r10, r11, r12
    sl.i32 r10, r11, r12
    sli.i32 r10, r11, 7
    sr.u32 r10, r11, r12
    sr.i32 r10, r11, r12
    sri.u32 r10, r11, 7
    sri.i32 r10, r11, 7
    jump.abs r0, 0(r1)
