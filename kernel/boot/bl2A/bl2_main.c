/* 
 * bl2_main.c
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


#include <stdint.h>
#include <soc.h>
#include "mm/heap.h"
#include "smp/smp.h"
#include <console_early.h>
#include <load.h>


static void load_kernel(void) {
    uint32_t tid   = csr_read(CSR_THREAD_ID);
    console_early_puts("[BL2] loading kernel ");
    uint32_t ntxns = KERNEL_SIZE / BLOCK_SIZE;
    for (uint32_t i = 0; i < ntxns; i++) {
        uint32_t src_block = (KERNEL_BASE_BA + i * BLOCK_SIZE) / BLOCK_SIZE;
        uint32_t dest_ppn  = (KERNEL_BASE    + i * PAGE_SIZE)  / PAGE_SIZE;
        load_block(src_block, dest_ppn);

        if ((i & 10) == 0) {
            console_early_puts(".");
        }
    }
    console_early_puts("\r\n");
}

void bl2_main(void) {
    uint32_t tid = csr_read(CSR_THREAD_ID);
    console_early_puts("[BL2] alive\r\n");
    heap_init(BL2_HEAP_BASE, BL2_HEAP_SIZE);
    smp_init();
    // console_early_puts("[BL2] ready\r\n");
    // load_kernel();
    // console_early_puts("[BL2] jumping to kernel\r\n");
    // __asm__ volatile ("fence.i" ::: "memory");
    // void (*kernel_entry)(void) = (void (*)(void))KERNEL_BASE;
    // kernel_entry();
    console_early_puts("[BL2A] ready and going to sleep\r\n");
    while (1) {
        wfi();
    }
}
