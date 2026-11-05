#include "mmio.h"
#include "../../boot/bl2/sync/spinlock.h"

#define UART_TXDATA      (UART_BASE + 0x00)
#define UART_RXDATA      (UART_BASE + 0x08)
#define UART_TXCTRL      (UART_BASE + 0x10)
#define UART_RXCTRL      (UART_BASE + 0x18)
#define UART_DIV         (UART_BASE + 0x30)

#define UART_TXDATA_FULL (UINT64_C(1) << 63)
#define UART_RXDATA_EMPTY (UINT64_C(1) << 63)
#define UART_TXCTRL_TXEN UINT64_C(1)
#define UART_RXCTRL_RXEN UINT64_C(1)
#define UART_DIV_FAST    UINT64_C(64)

static spinlock_t uart_lock = { .lock = SPINLOCK_UNLOCKED };

static void uart_putc_unlocked(char c) {
    while (reg64_read(UART_TXDATA) & UART_TXDATA_FULL)
        ;
    reg64_write(UART_TXDATA, (uint64_t)(uint8_t)c);
}

void uart_init(void) {
    reg64_write(UART_DIV, UART_DIV_FAST);
    reg64_write(UART_TXCTRL, UART_TXCTRL_TXEN);
    reg64_write(UART_RXCTRL, UART_RXCTRL_RXEN);
}

void uart_putc(char c) {
    spin_lock(&uart_lock);
    uart_putc_unlocked(c);
    spin_unlock(&uart_lock);
}

char uart_getc(void) {
    uint64_t val;
    do {
        val = reg64_read(UART_RXDATA);
    } while (val & UART_RXDATA_EMPTY);
    return (char)(val & 0xFF);
}

void uart_puts(const char *s) {
    spin_lock(&uart_lock);
    while (*s) {
        if (*s == '\n') uart_putc_unlocked('\r');
        uart_putc_unlocked(*s++);
    }
    spin_unlock(&uart_lock);
}

void uart_write_buffer(const char *buffer, uint64_t length) {
    spin_lock(&uart_lock);
    while (length--) {
        uart_putc_unlocked(*buffer++);
    }
    spin_unlock(&uart_lock);
}

void uart_acquire(void) {
    spin_lock(&uart_lock);
}

void uart_release(void) {
    spin_unlock(&uart_lock);
}
