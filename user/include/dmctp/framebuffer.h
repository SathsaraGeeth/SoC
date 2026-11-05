#ifndef DMCTP_FRAMEBUFFER_H
#define DMCTP_FRAMEBUFFER_H
#include <stdint.h>
#define FB_WIDTH 32u
#define FB_HEIGHT 32u
#define FB_STRIDE FB_WIDTH
#define FB_SIZE (FB_STRIDE * FB_HEIGHT)
#define FB_IOC_GET_INFO 0x4601u
#define FB_IOC_SET_POS  0x4602u
/* RGB332 indexed/direct color: RRRGGGBB. Eight pixels pack in one word. */
static inline uint8_t fb_rgb332(uint8_t r, uint8_t g, uint8_t b) {
    return (uint8_t)((r & 0xe0u) | ((g >> 3) & 0x1cu) | (b >> 6));
}
#endif
