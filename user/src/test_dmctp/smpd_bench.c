#include <stdint.h>
#include <unistd.h>
#include <dmctp/soc.h>
#include <dmctp/thread.h>



enum {
    MAX_WORKERS = THREADS_IN_CLUSTER,
    STACK_SIZE = 512,
    WORDS_PER_WORKER = 32,
    TOTAL_ITERATIONS = 32768
};

struct worker_arg {
    uint32_t id;
    uint32_t iterations;
};

static uint8_t worker_stacks[MAX_WORKERS][STACK_SIZE]
    __attribute__((aligned(16)));
static thread_t worker_threads[MAX_WORKERS];
static struct worker_arg worker_args[MAX_WORKERS];
static uint64_t packet_words[MAX_WORKERS][WORDS_PER_WORKER];
static volatile uint64_t packet_results[MAX_WORKERS];
static volatile uint32_t workers_ready;
static volatile uint32_t workers_done;
static volatile uint32_t start_flag;


static uint64_t divide_u64(uint64_t numerator, uint64_t denominator) {
    uint64_t quotient = 0;
    uint64_t remainder = 0;

    for (int bit = 63; bit >= 0; bit--) {
        remainder = (remainder << 1) | ((numerator >> bit) & 1u);
        if (remainder >= denominator) {
            remainder -= denominator;
            quotient |= 1ull << bit;
        }
    }
    return quotient;
}

static void packet_work(struct worker_arg *arg) {
    uint32_t id = arg->id;
    uint64_t flow_hash = 0xcbf29ce484222325ull ^ id;
    uint64_t checksum = id + 1u;

    for (uint32_t i = 0; i < WORDS_PER_WORKER; i++)
        packet_words[id][i] =
            ((uint64_t)(i + 1u) * 0x100000001b3ull) ^ ((uint64_t)id << 17);

    for (uint32_t packet = 0; packet < arg->iterations; packet++) {
        uint32_t index = (packet * 5u + id * 3u) & (WORDS_PER_WORKER - 1u);
        uint64_t word = packet_words[id][index];

        checksum += (word & 0xffffu) + ((word >> 16) & 0xffffu);
        flow_hash ^= word + packet;
        flow_hash *= 0x100000001b3ull;
        if ((word ^ flow_hash) & 0x8000u)
            flow_hash ^= flow_hash >> 29;
        else
            flow_hash += checksum << 7;
        packet_words[id][index] = flow_hash ^ checksum;
    }

    packet_results[id] = flow_hash ^ checksum;
}

static void *packet_worker(void *opaque) {
    struct worker_arg *arg = (struct worker_arg *)opaque;

    __atomic_add_fetch(&workers_ready, 1u, __ATOMIC_RELEASE);
    while (!__atomic_load_n(&start_flag, __ATOMIC_ACQUIRE))
        __asm__ volatile ("nop");
    packet_work(arg);
    __atomic_add_fetch(&workers_done, 1u, __ATOMIC_RELEASE);
    return 0;
}

static unsigned long long run_workers(uint32_t count, uint64_t *digest) {
    uint32_t made = 0;
    uint32_t base_iterations = TOTAL_ITERATIONS / count;
    uint32_t remainder = TOTAL_ITERATIONS % count;

    __atomic_store_n(&workers_ready, 0u, __ATOMIC_RELAXED);
    __atomic_store_n(&workers_done, 0u, __ATOMIC_RELAXED);
    __atomic_store_n(&start_flag, 0u, __ATOMIC_RELAXED);

    for (uint32_t i = 0; i < count; i++) {
        worker_args[i].id = i;
        worker_args[i].iterations = base_iterations + (i < remainder);
        if (i == 0)
            continue;
        if (thread_create(&worker_threads[i], packet_worker, &worker_args[i],
                          worker_stacks[i], sizeof(worker_stacks[i])) < 0)
            break;
        made++;
    }
    if (made != count - 1u) {
        __atomic_store_n(&start_flag, 1u, __ATOMIC_RELEASE);
        for (uint32_t i = 1; i <= made; i++)
            thread_join(worker_threads[i]);
        return 0;
    }

    while (__atomic_load_n(&workers_ready, __ATOMIC_ACQUIRE) != count - 1u)
        __asm__ volatile ("nop");
    unsigned long long start = get_time();
    __atomic_store_n(&start_flag, 1u, __ATOMIC_RELEASE);
    packet_work(&worker_args[0]);
    while (__atomic_load_n(&workers_done, __ATOMIC_ACQUIRE) != count - 1u)
        __asm__ volatile ("nop");
    unsigned long long elapsed = get_time() - start;

    for (uint32_t i = 1; i < count; i++)
        thread_join(worker_threads[i]);
    for (uint32_t i = 0; i < count; i++)
        *digest ^= packet_results[i];
    return elapsed ? elapsed : 1u;
}

int main(void) {
    unsigned long long baseline = 0;
    uint64_t digest = 0;

    printf("SMPD benchmark: %u total iterations, up to %u threads\n",
           TOTAL_ITERATIONS, MAX_WORKERS);
    puts("threads  time_us  speedup_x100  efficiency_pct  iter_per_sec\n");

    for (uint32_t count = 1; count <= MAX_WORKERS; count <<= 1) {
        unsigned long long elapsed = run_workers(count, &digest);
        if (!elapsed) {
            printf("SMPD benchmark: FAIL creating %u threads\n", count);
            return 1;
        }
        if (!baseline)
            baseline = elapsed;

        unsigned long long speedup_x100 =
            divide_u64(baseline * 100ull, elapsed);
        unsigned long long efficiency = divide_u64(speedup_x100, count);
        unsigned long long rate = divide_u64(
            (unsigned long long)TOTAL_ITERATIONS * 1000000000ull, elapsed);
        printf("%u  %llu  %llu  %llu  %llu\n", count,
               divide_u64(elapsed, 1000u), speedup_x100, efficiency, rate);
    }

    printf("SMPD benchmark: PASS digest=0x%llx\n", (unsigned long long)digest);
    return 0;
}
