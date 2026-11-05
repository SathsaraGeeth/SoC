/* 
 * smp_early.S - early SMP implementation
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



.global             release_aps
.global             ap_entry_fn
.global             ap_release_flag

release_aps:
    la              r11, ap_entry_fn
    store.64        r10, 0(r11)
    fence.d.ls.ls
    la              r11, ap_release_flag
    addi.i64        r12, r0, 1
    store.32        r12, 0(r11)
    jump.abs        r0, 0(r1) 

.section            .data
ap_entry_fn:        .dword 0
ap_release_flag:    .word 0
