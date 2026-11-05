#include "uart_dev.h"
#include "../core/dev.h"
#include "../../lib/printk.h"
#include <stdint.h>

extern void uart_putc(char);
extern char uart_getc(void);
extern void uart_puts(const char *);
extern void uart_write_buffer(const char *, uint64_t);

/* ── vnode ops for UART ──────────────────────────────────── */

static int uart_open(vnode_t *vn, int flags) {
    (void)vn; (void)flags;
    return 0;   /* always succeeds, already init'd by BL1 */
}

static int uart_close(vnode_t *vn) {
    (void)vn;
    return 0;   /* never really close a UART */
}

static int uart_read(vnode_t *vn, void *buf, size_t n, uint32_t *pos) {
    (void)vn; (void)pos;
    char *dst = (char *)buf;
    for (size_t i = 0; i < n; i++) {
        char c = uart_getc();
        dst[i] = c;
        if (c == '\n' || c == '\r') return (int)(i + 1);
    }
    return (int)n;
}

static int uart_write(vnode_t *vn, const void *buf, size_t n, uint32_t *pos) {
    (void)vn; (void)pos;
    uart_write_buffer((const char *)buf, n);
    return (int)n;
}

static int uart_ioctl(vnode_t *vn, uint32_t cmd, void *arg) {
    (void)vn; (void)cmd; (void)arg;
    return -1;  /* no ioctls yet */
}

vnode_ops_t uart_vnode_ops = {
    .open  = uart_open,
    .close = uart_close,
    .read  = uart_read,
    .write = uart_write,
    .ioctl = uart_ioctl,
};

void uart_dev_init(void) {
    dev_register("uart0", &uart_vnode_ops, 0);
}
