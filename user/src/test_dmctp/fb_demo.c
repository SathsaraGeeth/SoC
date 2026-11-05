#include <dmctp/framebuffer.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <dmctp/soc.h>
#include <dmctp/thread.h>

static uint8_t frame[FB_SIZE];
static uint8_t worker_stacks[FB_HEIGHT][256] __attribute__((aligned(16)));
static thread_t worker_threads[FB_HEIGHT];
static uint32_t worker_ids[FB_HEIGHT];
static volatile uint32_t worker_count;
static volatile uint32_t frame_generation;
static volatile uint32_t workers_done;

static void report_ms(const char *name, unsigned long long start,
                      unsigned long long end) {
    unsigned long long us = (end - start) / 1000ull;
    printf("fb_demo: %s %u us\n", name, (unsigned)(uint32_t)us);
}

static void draw_row(uint32_t y, uint32_t animation_frame) {
        for (uint32_t x = 0; x < FB_WIDTH; x++) {
            uint32_t phase = animation_frame & 31u;
            uint8_t r = (uint8_t)(((x + phase) & 31u) * 255u / 31u);
            uint8_t g = (uint8_t)(((y + phase) & 31u) * 255u / 31u);
            uint8_t b = (uint8_t)((((x ^ y) + phase) & 31u) * 8u);
            uint32_t box_x = animation_frame & 23u;
            if (x >= box_x && x < box_x + 8u && y >= 12u && y < 20u)
                r = g = b = 255;
            frame[y * FB_STRIDE + x] = fb_rgb332(r, g, b);
        }
}

static void *row_worker(void *arg) {
    uint32_t id = *(uint32_t *)arg;
    uint32_t seen_generation = 0;
    for (;;) {
        uint32_t generation;
        while ((generation = __atomic_load_n(&frame_generation,
                                               __ATOMIC_ACQUIRE)) == seen_generation)
            yield();
        seen_generation = generation;
        uint32_t count = __atomic_load_n(&worker_count, __ATOMIC_RELAXED);
        for (uint32_t y = id; y < FB_HEIGHT; y += count)
            draw_row(y, generation - 1u);
        __atomic_add_fetch(&workers_done, 1u, __ATOMIC_RELEASE);
    }
}

int main(void) {
    unsigned long long t0 = get_time();
    puts("fb_demo: drawing RGB332 with SoC-sized worker pool");
    unsigned long long t_create = get_time();
    puts("fb_demo: creating threads");
    uint32_t workers = THREADS_IN_CLUSTER < FB_HEIGHT ? THREADS_IN_CLUSTER : FB_HEIGHT;
    uint32_t made = 0;
    for (uint32_t i = 0; i < workers; i++) {
        worker_ids[made] = made;
        if (thread_create(&worker_threads[made], row_worker, &worker_ids[made],
                          worker_stacks[made], sizeof(worker_stacks[made])) == 0) {
            made++;
        } else {
            break;
        }
    }
    __atomic_store_n(&worker_count, made, __ATOMIC_RELEASE);
    unsigned long long t_created = get_time();
    report_ms("thread creation", t_create, t_created);
    puts("fb_demo: continuous animation running");
    for (uint32_t animation_frame = 0;; animation_frame++) {
        unsigned long long t_render = get_time();
        if (made) {
            __atomic_store_n(&workers_done, 0u, __ATOMIC_RELAXED);
            __atomic_store_n(&frame_generation, animation_frame + 1u,
                             __ATOMIC_RELEASE);
            while (__atomic_load_n(&workers_done, __ATOMIC_ACQUIRE) < made)
                yield();
        } else {
            for (uint32_t y = 0; y < FB_HEIGHT; y++)
                draw_row(y, animation_frame);
        }
        unsigned long long t_rendered = get_time();

        unsigned long long t_write = get_time();
        int fd = open("/dev/fb0", O_WRONLY);
        if (fd < 0) {
            puts("fb_demo: cannot open /dev/fb0");
            return 1;
        }
        if (write(fd, frame, sizeof(frame)) != (int)sizeof(frame)) {
            puts("fb_demo: framebuffer write failed");
            close(fd);
            return 1;
        }
        close(fd);
        unsigned long long t_written = get_time();
        if ((animation_frame & 15u) == 0) {
            printf("fb_demo: frame %u\n", animation_frame);
            report_ms("render", t_render, t_rendered);
            report_ms("fb open/write/close", t_write, t_written);
            report_ms("total since start", t0, t_written);
        }
    }
}
