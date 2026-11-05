#include <stdio.h>
#include <stdlib.h>
#include <dmctp/soc.h>
#include <sysarr/sysarr.h>
#include <unistd.h>

#define NATIVE_N 8u
#define DENSE_N 16u
#define DENSE_TILES (DENSE_N / SYSARR_HW_M)

static signed char native_a[NATIVE_N][NATIVE_N];
static signed char native_b[NATIVE_N][NATIVE_N];
static signed char native_d[NATIVE_N][NATIVE_N];
static sysarr_tile_t native_a_tile;
static sysarr_tile_t native_b_tile;
static sysarr_tile_t native_d_tile;
static signed char dense_a[DENSE_N * DENSE_N];
static signed char dense_b[DENSE_N * DENSE_N];
static signed char dense_d[DENSE_N * DENSE_N];

static void print_accelerator_measurement(const char *cycles_name,
                                          const char *time_name,
                                          unsigned long long cycles) {
    unsigned long long elapsed_ns =
        (cycles * 1000000000ULL) / (unsigned long long)CLOCK_FREQ_HZ;

    printf("%s%llu cycles\n", cycles_name, cycles);
    printf("%s%llu ns\n", time_name, elapsed_ns);
}

static void print_matrix(const char *name, const signed char *matrix, unsigned n) {
    printf("%s\n", name);
    for (unsigned row = 0; row < n; row++) {
        for (unsigned col = 0; col < n; col++) {
            printf("%d ", matrix[col]);
        }
        printf("\n");
        matrix += n;
    }
}

static int mul_i8_reference(signed char lhs, signed char rhs) {
    int negative = 0;
    int left = lhs;
    int right = rhs;
    int product = 0;

    if (left < 0) {
        left = -left;
        negative = !negative;
    }
    if (right < 0) {
        right = -right;
        negative = !negative;
    }
    while (right) {
        if (right & 1) product += left;
        left <<= 1;
        right >>= 1;
    }
    return negative ? -product : product;
}

static int dense_atb_matches_reference(const signed char *a,
                                       const signed char *b,
                                       const signed char *d) {
    const signed char *d_ptr = d;
    for (unsigned row = 0; row < DENSE_N; row++) {
        for (unsigned col = 0; col < DENSE_N; col++) {
            const signed char *a_ptr = a + row;
            const signed char *b_ptr = b + col;
            int expected = 0;
            for (unsigned k = 0; k < DENSE_N; k++) {
                expected += mul_i8_reference(*a_ptr, *b_ptr);
                a_ptr += DENSE_N;
                b_ptr += DENSE_N;
            }
            if (*d_ptr != (signed char)expected) {
                printf("[SYSARR] dense mismatch row=%u col=%u got=%d expected=%d\n",
                       row, col, *d_ptr, (signed char)expected);
                return -1;
            }
            d_ptr++;
        }
    }
    return 0;
}

static int exercise_native_8x8(int fd) {
    sysarr_tile_t *a = &native_a_tile;
    sysarr_tile_t *b = &native_b_tile;
    sysarr_tile_t *d = &native_d_tile;
    for (unsigned row = 0; row < NATIVE_N; row++) {
        for (unsigned col = 0; col < NATIVE_N; col++) {
            native_a[row][col] = (signed char)(((3 * row + 2 * col) & 7u) - 4);
            native_b[row][col] = (signed char)(((5 * row + 3 * col) & 7u) - 4);
        }
    }
    sysarr_pack_i8_tile(native_a, a);
    sysarr_pack_i8_tile(native_b, b);
    for (unsigned word = 0; word < SYSARR_WORDS_PER_TILE; word++) d->words[word] = 0;

    if (sysarr_atb_tile(fd, SYSARR_DTYPE_I8, SYSARR_DTYPE_I8,
                        SYSARR_DTYPE_I32, SYSARR_DTYPE_I8, a, b, d) < 0 ||
        sysarr_wait(fd) < 0) return -1;
    print_accelerator_measurement("[SYSARR] native accelerator: ",
                                  "[SYSARR] native accelerator time: ",
                                  sysarr_last_cycles(fd));

    sysarr_unpack_i8_tile(d, native_d);
    print_matrix("[SYSARR] native 8x8 output", &native_d[0][0], NATIVE_N);
    return 0;
}

static int exercise_dense_16x16(int fd) {
    signed char *a = dense_a;
    signed char *b = dense_b;
    signed char *d = dense_d;
    sysarr_request_t commands[2];

    /* Touch every mapped page before sys_core accesses these virtual addresses. */
    printf("[SYSARR] dense: populating mapped pages\n");
    for (unsigned k = 0; k < DENSE_N; k++) {
        for (unsigned col = 0; col < DENSE_N; col++) {
            a[k * DENSE_N + col] = (signed char)(((3 * k + 2 * col) & 7u) - 4);
            b[k * DENSE_N + col] = (signed char)(((5 * k + 3 * col) & 7u) - 4);
            d[k * DENSE_N + col] = 0;
        }
    }
    printf("[SYSARR] dense: pages ready\n");

    if (sysarr_make_dense_atb_command(a, b, DENSE_TILES, DENSE_TILES,
                                      &commands[0]) < 0) return -1;
    sysarr_make_dense_wb_command(d, &commands[1]);
    sysarr_set_command_mac_type(&commands[0], SYSARR_MAC_INT8);
    sysarr_set_command_mac_type(&commands[1], SYSARR_MAC_INT8);
    printf("[SYSARR] dense: submitting 16x16 command\n");
    if (sysarr_submit_many(fd, commands, 2) < 0 || sysarr_wait(fd) < 0)
        return -1;
    print_accelerator_measurement("[SYSARR] dense accelerator: ",
                                  "[SYSARR] dense accelerator time: ",
                                  sysarr_last_cycles(fd));

    print_matrix("[SYSARR] dense 16x16 output", d, DENSE_N);
    if (dense_atb_matches_reference(a, b, d) < 0) return -1;
    return 0;
}

int main(void) {
    int fd = sysarr_open();
    if (fd < 0) return 1;

    printf("[SYSARR] mapped native 8x8 exercise\n");
    if (exercise_native_8x8(fd) < 0) return 2;
    printf("[SYSARR] mapped dense 16x16 exercise\n");
    if (exercise_dense_16x16(fd) < 0) return 3;
    close(fd);
    printf("[SYSARR] exercises passed\n");
    return 0;
}
