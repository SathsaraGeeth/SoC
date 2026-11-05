/* 
 * kernel/boot/common/console_early.c
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

/*
 * Comments:
 * 1. Early UART bring up.
 * 2. Not thread safe, used only in early boot stage.
 */

#include <stdint.h>
#include <console_early.h>

/* Helpers */
static inline void reg64_write(uintptr_t addr, uint64_t val) {
    *(volatile uint64_t *)addr = val;
}
static inline uint64_t reg64_read(uintptr_t addr) {
    return *(volatile uint64_t *)addr;
}


void console_early_init(void) {
    reg64_write(UART_DIV, UART_DIV_FAST);
    reg64_write(UART_TXCTRL, UART_TXCTRL_TXEN);
    reg64_write(UART_RXCTRL, UART_RXCTRL_RXEN);
}

void console_early_putc(char c) {
    while (reg64_read(UART_TXDATA) & UART_TXDATA_FULL) {
        /* wait untill the buffers becomes free */
    }
    reg64_write(UART_TXDATA, (uint64_t)(uint8_t)c);
}

char console_early_getc(void) {
    uint64_t val;
    do {
        val = reg64_read(UART_RXDATA);
    } while (val & UART_RXDATA_EMPTY);
    return (char)(val & 0xFF);
}

void console_early_puts(const char *s) {
    while (*s) {
        if (*s == '\n') console_early_putc('\r');
        console_early_putc(*s++);
    }
}

void console_early_puthex32(uint32_t value) {
    char buf[] = "0x00000000";
    for (int i = 9; i >= 2; i--) {
        uint8_t nibble = value & 0xF;
        buf[i] = (nibble < 10) ? ('0' + nibble) : ('a' + nibble - 10);
        value >>= 4;
    }
    console_early_puts(buf);
}

void console_early_putdec32(uint32_t value) {
    char digits[10];
    int n = 0;

    do {
        uint32_t q = 0, r = 0;
        for (int bit = 31; bit >= 0; bit--) {
            r = (r << 1) | ((value >> bit) & 1u);
            if (r >= 10) {
                r -= 10;
                q |= 1u << bit;
            }
        }
        digits[n++] = (char)('0' + r);
        value = q;
    } while (value);

    while (n) console_early_putc(digits[--n]);
}
