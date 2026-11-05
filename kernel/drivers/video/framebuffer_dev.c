#include "framebuffer_dev.h"
#include "../core/dev.h"
#include "../../lib/printk.h"
#include "../../dmtcp/include/soc.h"
#include <stdint.h>
#include <stddef.h>

#define FB_WIDTH  FRAMEBUFFER_WIDTH
#define FB_HEIGHT FRAMEBUFFER_HEIGHT
#define FB_BPP    FRAMEBUFFER_BPP
#define FB_SIZE   FRAMEBUFFER_SIZE
#define FB_BASE   FRAMEBUFFER_BASE
#define FB_IOC_GET_INFO 0x4601u
#define FB_IOC_SET_POS  0x4602u

typedef struct { uint32_t width, height, stride, format; } fb_info_t;

static int fb_open(vnode_t *vn, int flags) { (void)vn; (void)flags; return 0; }
static int fb_close(vnode_t *vn) { (void)vn; return 0; }
static int fb_read(vnode_t *vn, void *buf, size_t n, uint32_t *pos) {
    (void)vn; (void)buf; (void)n; (void)pos; return -1;
}
static int fb_write(vnode_t *vn, const void *buf, size_t n, uint32_t *pos) {
    (void)vn;
    if (!buf || *pos >= FB_SIZE) return 0;
    if (n > FB_SIZE - *pos) n = FB_SIZE - *pos;
    const uint8_t *src = (const uint8_t *)buf;
    size_t i = 0;
    
    while (i + sizeof(uint64_t) <= n) {
        uint64_t word = 0;
        for (uint32_t b = 0; b < sizeof(word); b++)
            word |= (uint64_t)src[i + b] << (b * 8);
        *(volatile uint64_t *)(uintptr_t)(FB_BASE + *pos + i) = word;
        i += sizeof(word);
    }
    while (i < n) {
        *(volatile uint8_t *)(uintptr_t)(FB_BASE + *pos + i) = src[i];
        i++;
    }
    *pos += (uint32_t)n;
    return (int)n;
}
static int fb_ioctl(vnode_t *vn, uint32_t cmd, void *arg) {
    (void)vn;
    if (!arg) return -1;
    if (cmd == FB_IOC_GET_INFO) {
        *(fb_info_t *)arg = (fb_info_t){ FB_WIDTH, FB_HEIGHT, FB_WIDTH * FB_BPP, 2 };
        return 0;
    }
    return -1;
}
static vnode_ops_t fb_ops = { fb_open, fb_close, fb_read, fb_write, fb_ioctl };
void framebuffer_dev_init(void) {
    dev_register("fb0", &fb_ops, 0);
    printk("[FB] /dev/fb0 %dx%d RGB332 (8 pixels/word) region0\r\n", FB_WIDTH, FB_HEIGHT);
}
