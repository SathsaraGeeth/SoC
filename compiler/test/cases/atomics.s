    .text
    .globl atomic_instructions
atomic_instructions:
    load.i32.res r10, (r11)
    load.i32.res.aq r10, (r11)
    load.i64.res r10, (r11)
    load.i64.res.aq r10, (r11)
    condstore.8 r10, r12, (r11)
    condstore.16 r10, r12, (r11)
    condstore.32 r10, r12, (r11)
    condstore.64 r10, r12, (r11)
    condstore.8.rl r10, r12, (r11)
    condstore.16.rl r10, r12, (r11)
    condstore.32.rl r10, r12, (r11)
    condstore.64.rl r10, r12, (r11)
    jump.abs r0, 0(r1)
