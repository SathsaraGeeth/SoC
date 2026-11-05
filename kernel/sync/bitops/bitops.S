/*
 * kernel/sync/bitops/bitops.S
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

.global set_bit
.global clear_bit
.global test_bit
.global test_and_set_bit
.global test_and_clear_bit
.global test_and_change_bit

/*
 * Uses:
 *
 * r10 = bit index / return value
 * r11 = address
 *
 * r5  = old value
 * r6  = new value
 * r7  = SC result
 * r8  = bit mask
 *
 * r1  = return address
 */

set_bit:
    addi.i64         r8, r0, 1
    sl.i64           r8, r8, r10
1:
    load.i64.res.aq  r5, 0(r11)
    or.64            r6, r5, r8
    condstore.64.rl  r7, r6, 0(r11)
    bc.ne            r7, r0, 1b
    jump.abs         r0, 0(r1)

clear_bit:
    addi.i64         r8, r0, 1
    sl.i64           r8, r8, r10
    xori.64          r8, r8, -1
1:
    load.i64.res.aq  r5, 0(r11)
    and.64           r6, r5, r8
    condstore.64.rl  r7, r6, 0(r11)
    bc.ne            r7, r0, 1b
    jump.abs         r0, 0(r1)

test_bit:
    load.i64         r5, 0(r11)
    sr.u64           r5, r5, r10
    andi.64          r10, r5, 1
    jump.abs         r0, 0(r1)

test_and_set_bit:
    addi.i64         r8, r0, 1
    sl.i64           r8, r8, r10
1:
    load.i64.res.aq  r5, 0(r11)
    or.64            r6, r5, r8
    condstore.64.rl  r7, r6, 0(r11)
    bc.ne            r7, r0, 1b
    and.64           r10, r5, r8
    slt.u64          r10, r0, r10
    jump.abs         r0, 0(r1)

test_and_clear_bit:
    addi.i64         r8, r0, 1
    sl.i64           r8, r8, r10
1:
    load.i64.res.aq  r5, 0(r11)
    xor.64           r6, r5, r8
    and.64           r6, r5, r6
    condstore.64.rl  r7, r6, 0(r11)
    bc.ne            r7, r0, 1b
    and.64           r10, r5, r8
    slt.u64          r10, r0, r10
    jump.abs         r0, 0(r1)

test_and_change_bit:
    addi.i64         r8, r0, 1
    sl.i64           r8, r8, r10
1:
    load.i64.res.aq  r5, 0(r11)
    xor.64           r6, r5, r8
    condstore.64.rl  r7, r6, 0(r11)
    bc.ne            r7, r0, 1b
    and.64           r10, r5, r8
    slt.u64          r10, r0, r10
    jump.abs         r0, 0(r1)
