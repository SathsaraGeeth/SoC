/* 
 * kernel/lib/printk.c
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
 * 1. First uses early_console
 * 2. Then after driver init switch to uart0
 */

#include "printk.h"
#include <console_early.h>
#include <stdarg.h>
#include <stdint.h>
#include "../sync/spinlock.h"

static spinlock_t printk_lock = {SPINLOCK_UNLOCKED};

/* start with early console*/
static void (*console_putc)(char c) = 0;

static const char digits[] = "0123456789abcdef";

static uint32_t udivmod32(uint32_t value, uint32_t base, uint32_t *remainder) {
    uint32_t quotient = 0, rem = 0;
    for (int bit = 31; bit >= 0; bit--) {
        rem = (rem << 1) | ((value >> bit) & 1u);
        if (rem >= base) {
            rem -= base;
            quotient |= UINT32_C(1) << bit;
        }
    }
    if (remainder) *remainder = rem;
    return quotient;
}


void printk_init(void (*putc_fn)(char c)) {
    console_putc = putc_fn;
}

void printk_switch(void (*putc_fn)(char c)) {
    console_putc = putc_fn;
}

static inline void putc(char c) {
    if (console_putc) {
        console_putc(c);
    }
}

static void print_str(const char *s) {
    if (!s) { s = "(null)"; }
    while (*s) {
        if (*s == '\n') putc('\r');
        putc(*s++);
    }
}

static void utoa(uint32_t val, int base, char *buf) {
    char tmp[32];
    int i = 0;
    if (val == 0) {
        buf[0] = '0';
        buf[1] = 0;
        return;
    }
    while (val > 0) {
        uint32_t remainder;
        val = udivmod32(val, (uint32_t)base, &remainder);
        tmp[i++] = digits[remainder];
    }
    int j = 0;
    while (i > 0)
        buf[j++] = tmp[--i];

    buf[j] = 0;
}

static void itoa(int32_t val, char *buf) {
    if (val < 0) {
        buf[0] = '-';
        utoa((uint32_t)(-val), 10, buf + 1);
    } else {
        utoa((uint32_t)val, 10, buf);
    }
}

void printk(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    if (!console_putc) {
        va_end(args);
        return;
    }

    spin_lock(&printk_lock);

    while (*fmt) {
        if (*fmt != '%') {
            if (*fmt == '\n')
                putc('\r');
            putc(*fmt++);
            continue;
        }
        fmt++;

        char buf[64];
        switch (*fmt) {
        case 'd':
            itoa(va_arg(args, int32_t), buf);
            print_str(buf);
            break;
        case 'u':
            utoa(va_arg(args, uint32_t), 10, buf);
            print_str(buf);
            break;
        case 'x':
            utoa(va_arg(args, uint32_t), 16, buf);
            print_str(buf);
            break;
        case 'p':
            print_str("0x");
            utoa(va_arg(args, uint32_t), 16, buf);
            print_str(buf);
            break;
        case 's':
            print_str(va_arg(args, const char *));
            break;
        case 'c':
            putc((char)va_arg(args, int));
            break;
        case '%':
            putc('%');
            break;
        default:
            putc('%');
            putc(*fmt);
            break;
        }
        fmt++;
    }
    spin_unlock(&printk_lock);
    va_end(args);
}
