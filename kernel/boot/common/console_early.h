/* 
 * kernel/boot/common/console_early.h
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
 * 1. Early console bring up.
 * 2. Locks are not implemented, so not thread safe.
 */

#include <soc.h>


#define UART_TXDATA             (UART_BASE + 0x00)
#define UART_RXDATA             (UART_BASE + 0x08)
#define UART_TXCTRL             (UART_BASE + 0x10)
#define UART_RXCTRL             (UART_BASE + 0x18)
#define UART_DIV                (UART_BASE + 0x30)

#define UART_TXDATA_FULL        (UINT64_C(1) << 63)
#define UART_RXDATA_EMPTY       (UINT64_C(1) << 63)
#define UART_TXCTRL_TXEN        UINT64_C(1)
#define UART_RXCTRL_RXEN        UINT64_C(1)
#define UART_DIV_FAST           UINT64_C(64)
void console_early_init(void);
void console_early_putc(char c);
char console_early_getc(void);
void console_early_puts(const char *s);
void console_early_puthex32(uint32_t value);
void console_early_putdec32(uint32_t value);
