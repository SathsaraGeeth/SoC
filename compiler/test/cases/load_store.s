    .text
    .globl load_store_instructions
load_store_instructions:
    load.i8 r10, 0(r11)
    load.i16 r10, 2(r11)
    load.i32 r10, 4(r11)
    load.i64 r10, 8(r11)
    load.u8 r10, 16(r11)
    load.u16 r10, 18(r11)
    load.u32 r10, 20(r11)
    store.8 r10, 24(r11)
    store.16 r10, 26(r11)
    store.32 r10, 28(r11)
    store.64 r10, 32(r11)
    jump.abs r0, 0(r1)
