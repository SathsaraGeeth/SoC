#include <stdio.h>
#include <unistd.h>
#include <dmctp/soc.h>
#include <math/fp8.h>
#include <sysarr/sysarr.h>

#define NATIVE_N 8u
#define DENSE_N 16u
#define DENSE_TILES (DENSE_N / SYSARR_HW_M)

static fp8_e4m3_t native_a[NATIVE_N][NATIVE_N];
static fp8_e4m3_t native_b[NATIVE_N][NATIVE_N];
static fp8_e4m3_t native_d[NATIVE_N][NATIVE_N];
static sysarr_tile_t native_a_tile;
static sysarr_tile_t native_b_tile;
static sysarr_tile_t native_d_tile;
static fp8_e4m3_t dense_a[DENSE_N * DENSE_N]
    __attribute__((aligned(SYSARR_VECTOR_ALIGNMENT)));
static fp8_e4m3_t dense_b[DENSE_N * DENSE_N]
    __attribute__((aligned(SYSARR_VECTOR_ALIGNMENT)));
static fp8_e4m3_t dense_d[DENSE_N * DENSE_N]
    __attribute__((aligned(SYSARR_VECTOR_ALIGNMENT)));

static const fp8_e4m3_t a_values[] = {
    0x28, 0x30, 0x38, 0x40, 0xa8, 0xb0, 0xb8, 0xc0,
};
static const fp8_e4m3_t b_values[] = {
    0x20, 0x28, 0x30, 0x38, 0xa0, 0xa8, 0xb0, 0xb8,
};

static void print_matrix(const char *name, const fp8_e4m3_t *matrix,
                         unsigned size) {
    printf("%s\n", name);
    for (unsigned row = 0; row < size; row++) {
        for (unsigned col = 0; col < size; col++) {
            printf("%F ", matrix[row * size + col]);
        }
        printf("\n");
    }
}

static void populate(fp8_e4m3_t *a, fp8_e4m3_t *b, fp8_e4m3_t *d,
                     unsigned size) {
    for (unsigned row = 0; row < size; row++) {
        for (unsigned col = 0; col < size; col++) {
            a[row * size + col] =
                a_values[(3 * row + 5 * col) % (sizeof(a_values) / sizeof(a_values[0]))];
            b[row * size + col] =
                b_values[(5 * row + 3 * col + 1) % (sizeof(b_values) / sizeof(b_values[0]))];
            d[row * size + col] = 0;
        }
    }
}

static int exercise_native(int fd) {
    populate(&native_a[0][0], &native_b[0][0], &native_d[0][0], NATIVE_N);
    sysarr_pack_fp8_tile(native_a, &native_a_tile);
    sysarr_pack_fp8_tile(native_b, &native_b_tile);
    for (unsigned word = 0; word < SYSARR_WORDS_PER_TILE; word++)
        native_d_tile.words[word] = 0;

    if (sysarr_atb_tile(fd, SYSARR_DTYPE_FP8, SYSARR_DTYPE_FP8,
                        SYSARR_DTYPE_FP32, SYSARR_DTYPE_FP8,
                        &native_a_tile, &native_b_tile,
                        &native_d_tile) < 0 ||
        sysarr_wait(fd) < 0)
        return -1;

    sysarr_unpack_fp8_tile(&native_d_tile, native_d);
    printf("[SYSARR-FP8] native 8x8: %llu cycles\n",
           sysarr_last_cycles(fd));
    print_matrix("[SYSARR-FP8] native 8x8 output",
                 &native_d[0][0], NATIVE_N);
    return 0;
}

static int exercise_dense(int fd) {
    sysarr_request_t commands[2];

    populate(dense_a, dense_b, dense_d, DENSE_N);
    if (sysarr_make_dense_atb_command(dense_a, dense_b,
                                      DENSE_TILES, DENSE_TILES,
                                      &commands[0]) < 0)
        return -1;
    sysarr_make_dense_wb_command(dense_d, &commands[1]);
    sysarr_set_command_mac_type(&commands[0], SYSARR_MAC_FP8);
    sysarr_set_command_mac_type(&commands[1], SYSARR_MAC_FP8);

    if (sysarr_submit_many(fd, commands, 2) < 0 || sysarr_wait(fd) < 0)
        return -1;
    printf("[SYSARR-FP8] dense 16x16: %llu cycles\n",
           sysarr_last_cycles(fd));
    print_matrix("[SYSARR-FP8] dense 16x16 output", dense_d, DENSE_N);
    return 0;
}

int main(void) {
    int fd;

    fd = sysarr_open();
    if (fd < 0) return 1;
    if (exercise_native(fd) < 0) return 2;
    if (exercise_dense(fd) < 0) return 3;
    close(fd);
    printf("[SYSARR-FP8] exercises completed\n");
    return 0;
}
