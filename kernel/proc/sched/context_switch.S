/* Direct register context switch for the DMCTP64 task scheduler. */
.section .text
.global context_switch
.align 4

context_switch:
    store.64 r1,  0(r10)
    store.64 r2,  8(r10)
    store.64 r8,  56(r10)
    store.64 r9,  64(r10)
    store.64 r18, 136(r10)
    store.64 r19, 144(r10)
    store.64 r20, 152(r10)
    store.64 r21, 160(r10)
    store.64 r22, 168(r10)
    store.64 r23, 176(r10)
    store.64 r24, 184(r10)
    store.64 r25, 192(r10)
    store.64 r26, 200(r10)
    store.64 r27, 208(r10)

    load.i64 r1,  0(r11)
    load.i64 r12, 248(r11)
    bc.ne    r1, r0, 1f
    addi.i64 r1, r12, 0
1:
    load.i64 r2,  8(r11)
    load.i64 r8,  56(r11)
    load.i64 r9,  64(r11)
    load.i64 r18, 136(r11)
    load.i64 r19, 144(r11)
    load.i64 r20, 152(r11)
    load.i64 r21, 160(r11)
    load.i64 r22, 168(r11)
    load.i64 r23, 176(r11)
    load.i64 r24, 184(r11)
    load.i64 r25, 192(r11)
    load.i64 r26, 200(r11)
    load.i64 r27, 208(r11)
    ret
