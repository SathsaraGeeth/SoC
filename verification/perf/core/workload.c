#include <stdint.h>

#ifndef PERF_ITERATIONS
#define PERF_ITERATIONS 512
#endif

#define DONE_ADDRESS ((volatile uint64_t *)0x100000UL)

volatile uint64_t packet_words[32][32];
volatile uint64_t packet_results[32];

static inline uint64_t hardware_thread_id(void) {
    uint64_t id;
    __asm__ volatile ("csrr %0, 6" : "=r"(id));
    return id;
}

int main(void) {
    const uint64_t thread = hardware_thread_id();
    uint64_t flow_hash = 0xcbf29ce484222325ULL ^ thread;
    uint64_t checksum = thread + 1;

    for (uint64_t i = 0; i < 32; ++i)
        packet_words[thread][i] = (i + 1) * 0x100000001b3ULL ^ (thread << 17);

    for (uint64_t packet = 0; packet < PERF_ITERATIONS; ++packet) {
        const uint64_t index = (packet * 5 + thread * 3) & 31U;
        uint64_t word = packet_words[thread][index];

        checksum += (word & 0xffffU) + ((word >> 16) & 0xffffU);
        flow_hash ^= word + packet;
        flow_hash *= 0x100000001b3ULL;

        if ((word ^ flow_hash) & 0x8000U)
            flow_hash ^= flow_hash >> 29;
        else
            flow_hash += checksum << 7;

        packet_words[thread][index] = flow_hash ^ checksum;
        __asm__ volatile ("" : "+r"(flow_hash), "+r"(checksum));
    }

    packet_results[thread] = flow_hash ^ checksum;
    *DONE_ADDRESS = packet_results[thread];
    return 0;
}
