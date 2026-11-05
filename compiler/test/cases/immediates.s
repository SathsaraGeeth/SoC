    .text
    .globl immediate_boundaries
immediate_boundaries:
    lui r10, 0x54321
    addi.i64 r10, r11, -2048
    addi.i64 r10, r11, 2047
    andi.64 r10, r11, -1
    ori.64 r10, r11, 0
    xori.64 r10, r11, 2047
    sli.i64 r10, r11, 0
    sli.i64 r10, r11, 63
    jump.abs r0, 0(r1)
