/*
 * kernel/sync/atomic/atomic.S
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

.section .text

.global atomic_read_aint64
.global atomic_read_aint32
.global atomic_write_aint64
.global atomic_write_aint32
.global atomic_add_aint64
.global atomic_add_aint32
.global atomic_cmpxchg_aint64
.global atomic_cmpxchg_aint32

/*
 * Uses:
 * r10 = ptr
 * r11 = value / expected
 * r12 = desired
 * r5  = old value
 * r6  = new value
 * r7  = SC result
 * and in ABI
 * r1  = return address
 * r2  = sp
 */

atomic_read_aint64:
    load.i64        r10, 0(r10)
    jump.abs        r0, 0(r1)

atomic_read_aint32:
    load.i32        r10, 0(r10)
    jump.abs        r0, 0(r1)

atomic_write_aint64:
    store.64        r11, 0(r10)
    jump.abs        r0, 0(r1)

atomic_write_aint32:
    store.32        r11, 0(r10)
    jump.abs        r0, 0(r1)

atomic_add_aint64:
1:
    load.i64.res.aq r5, 0(r10)
    add.i64         r6, r5, r11
    condstore.64.rl r7, r6, 0(r10)
    bc.ne           r7, r0, 1b
    addi.i64        r10, r6, 0
    jump.abs        r0, 0(r1)

atomic_add_aint32:
1:
    load.i32.res.aq r5, 0(r10)
    add.i32         r6, r5, r11
    condstore.32.rl r7, r6, 0(r10)
    bc.ne           r7, r0, 1b
    addi.i32        r10, r6, 0
    jump.abs        r0, 0(r1)

atomic_cmpxchg_aint64:
1:
    load.i64.res.aq r5, 0(r10)
    bc.ne           r5, r11, 2f
    condstore.64.rl r7, r12, 0(r10)
    bc.ne           r7, r0, 1b
2:
    addi.i64        r10, r5, 0
    jump.abs        r0, 0(r1)

atomic_cmpxchg_aint32:
1:
    load.i32.res.aq r5, 0(r10)
    bc.ne           r5, r11, 2f
    condstore.32.rl r7, r12, 0(r10)
    bc.ne           r7, r0, 1b
2:
    addi.i32        r10, r5, 0
    jump.abs        r0, 0(r1)
