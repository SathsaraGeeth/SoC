/*
 * Comments:
 * 1. First use early_console
 * 2. Then after driver init switch to uart0
 */

#ifndef PRINTK_H
#define PRINTK_H
#include <stdarg.h>
#include <stdint.h>

void printk(const char *fmt, ...);
void printk_init(void (*putc_fn) (char c));
void printk_switch(void (*putc_fn) (char c));

#endif /* PRINTK_H */
