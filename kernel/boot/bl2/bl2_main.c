#include <stdint.h>
#include <soc.h>
#include "mm/heap.h"
#include "smp/smp.h"
#include <console_early.h>
#include <load.h>
#include <regs.h>

static uint32_t timer_us(void) {
    volatile uint32_t *mtime = (volatile uint32_t *)TIMER_MMIO_BASE;
    uint32_t hi, lo, hi_check;
    uint64_t ticks;
    do { hi = mtime[1]; lo = mtime[0]; hi_check = mtime[1]; } while (hi != hi_check);
    ticks = ((uint64_t)hi << 32) | lo;
    return (uint32_t)(ticks / (CLOCK_FREQ_HZ / 1000000ULL));
}

static void print_elapsed(const char *label, uint32_t start) {
    console_early_puts(label);
    console_early_putdec32(timer_us() - start);
    console_early_puts(" us\r\n");
}


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
    uint32_t boot_start = timer_us();
    console_early_puts("[BL2] alive\r\n");
    heap_init(BL2_HEAP_BASE, BL2_HEAP_SIZE);
    smp_init();
    console_early_puts("[BL2] ready\r\n");
    print_elapsed("[TIME] BL2 setup: ", boot_start);
    uint32_t load_start = timer_us();
    load_kernel();
    print_elapsed("[TIME] BL2 load kernel: ", load_start);
    print_elapsed("[TIME] BL2 total: ", boot_start);
    console_early_puts("[BL2] entering kernel in S-mode\r\n");
    __asm__ volatile ("fence.i" ::: "memory");

    uintptr_t medeleg = (1UL << CAUSE_MISALIGNED_FETCH) |
                        (1UL << CAUSE_FETCH_ACCESS) |
                        (1UL << CAUSE_ILLEGAL_INST) |
                        (1UL << CAUSE_BREAKPOINT) |
                        (1UL << CAUSE_MISALIGNED_LOAD) |
                        (1UL << CAUSE_LOAD_ACCESS) |
                        (1UL << CAUSE_MISALIGNED_STORE) |
                        (1UL << CAUSE_STORE_ACCESS) |
                        (1UL << CAUSE_ECALL_U) |
                        (1UL << CAUSE_FETCH_PAGE_FAULT) |
                        (1UL << CAUSE_LOAD_PAGE_FAULT) |
                        (1UL << CAUSE_STORE_PAGE_FAULT);
    csr_write(CSR_MEDELEG, medeleg);
    csr_write(CSR_MIDELEG, 1UL << 7);
    csr_write(CSR_MEPC, KERNEL_BASE);
    csr_write(CSR_MSTATUS, MSTATUS_MPP_S | MSTATUS_MPIE);
    mret();
    __builtin_unreachable();
}
