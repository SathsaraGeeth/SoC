#include "timer.h"
#include "../core/dev.h"
#include "../../dmtcp/include/soc.h"
#include "../../lib/printk.h"
#include "../../dmtcp/include/regs.h"
#include <stddef.h>

// Assuming standard mtime structure (64-bit mtime, 64-bit mtimecmp)
// In 32-bit RV, these need to be written as two 32-bit accesses.
#define MTIME_LOW     (*(volatile uint32_t*)(TIMER_MMIO_BASE + 0x00))
#define MTIME_HIGH    (*(volatile uint32_t*)(TIMER_MMIO_BASE + 0x04))
#define MTIMECMP_LOW  (*(volatile uint32_t*)(TIMER_MMIO_BASE + 0x08))
#define MTIMECMP_HIGH (*(volatile uint32_t*)(TIMER_MMIO_BASE + 0x0C))

// A tick interval based on the clock frequency
// e.g. 10ms tick -> CLOCK_FREQ_HZ / 100
#define TICK_INTERVAL (CLOCK_FREQ_HZ / 100)
#define TIMER_DELAY_SAMPLES 16

static int timer_open(vnode_t *vn, int flags) {
    (void)vn;
    (void)flags;
    return 0;
}

static int timer_close(vnode_t *vn) {
    (void)vn;
    return 0;
}

static int timer_read(vnode_t *vn, void *buf, size_t n, uint32_t *pos) {
    (void)vn;
    (void)pos;
    if (n < sizeof(uint64_t)) return -1;

    uint64_t *out = (uint64_t *)buf;
    *out = timer_get_time();
    return (int)sizeof(uint64_t);
}

static int timer_write(vnode_t *vn, const void *buf, size_t n, uint32_t *pos) {
    (void)vn;
    (void)buf;
    (void)n;
    (void)pos;
    return -1;
}

static int timer_ioctl(vnode_t *vn, uint32_t cmd, void *arg) {
    (void)vn;
    (void)cmd;
    (void)arg;
    return -1;
}

static vnode_ops_t timer_vnode_ops = {
    .open  = timer_open,
    .close = timer_close,
    .read  = timer_read,
    .write = timer_write,
    .ioctl = timer_ioctl,
};

uint64_t timer_get_time(void) {
    uint32_t hi, lo, hi_check;
    do {
        hi = MTIME_HIGH;
        lo = MTIME_LOW;
        hi_check = MTIME_HIGH;
    } while (hi != hi_check);
    return ((uint64_t)hi << 32) | lo;
}

static void set_mtimecmp(uint64_t cmp) {
    // Write high word as -1 to prevent spurious interrupts while setting low word
    MTIMECMP_HIGH = 0xFFFFFFFF;
    MTIMECMP_LOW = (uint32_t)cmp;
    MTIMECMP_HIGH = (uint32_t)(cmp >> 32);
}

static void timer_print_read_delay(void) {
    uint32_t min_delta = UINT32_MAX;
    uint32_t max_delta = 0;
    uint32_t total_delta = 0;

    for (uint32_t i = 0; i < TIMER_DELAY_SAMPLES; i++) {
        uint64_t start = timer_get_time();
        uint64_t end = timer_get_time();
        uint32_t delta = (uint32_t)(end - start);

        if (delta < min_delta) min_delta = delta;
        if (delta > max_delta) max_delta = delta;
        total_delta += delta;
    }

    printk("[TIMER] read delay ns: min=%u max=%u avg=%u samples=%u\n",
           min_delta,
           max_delta,
           total_delta / TIMER_DELAY_SAMPLES,
           TIMER_DELAY_SAMPLES);
}

void timer_init(void) {
    printk("[TIMER] initializing timer\n");
    dev_register("timer0", &timer_vnode_ops, 0);
    timer_print_read_delay();

    uint64_t now = timer_get_time();
    set_mtimecmp(now + TICK_INTERVAL);
    
    /* MTI is delegated by BL2, so S-mode controls it through sie[7]. */
    uintptr_t sie = csr_read(CSR_SIE);
    csr_write(CSR_SIE, sie | (1UL << 7));

    uintptr_t sstatus = csr_read(CSR_SSTATUS);
    csr_write(CSR_SSTATUS, sstatus | SSTATUS_SIE);
}

void timer_handle_irq(context_t *ctx) {
    uint64_t now = timer_get_time();
    set_mtimecmp(now + TICK_INTERVAL);

    scheduler_tick();
    if (need_resched())
        schedule_from_trap(ctx);
}
