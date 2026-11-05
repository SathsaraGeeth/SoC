#include <sysarr/sysarr.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>

#if SYSARR_HW_MAC_T == SYSARR_HW_MAC20I || \
    SYSARR_HW_MAC_T == SYSARR_HW_MACFP8INT8
/* Runtime-select hardware resets to INT8, so report INT8 as its active mode. */
static const sysarr_caps_t sysarr_truth_caps = {
    .m = SYSARR_HW_M,
    .a_type = SYSARR_DTYPE_I8,
    .b_type = SYSARR_DTYPE_I8,
    .acc_type = SYSARR_DTYPE_I32,
    .d_type = SYSARR_DTYPE_I8,
    .max_batch = 8192,
};
#elif SYSARR_HW_MAC_T == SYSARR_HW_MACFP8
static const sysarr_caps_t sysarr_truth_caps = {
    .m = SYSARR_HW_M,
    .a_type = SYSARR_DTYPE_FP8,
    .b_type = SYSARR_DTYPE_FP8,
    .acc_type = SYSARR_DTYPE_FP32,
    .d_type = SYSARR_DTYPE_FP8,
    .max_batch = 8192,
};
#else
static const sysarr_caps_t sysarr_truth_caps = {
    .m = 0,
    .a_type = SYSARR_DTYPE_I8,
    .b_type = SYSARR_DTYPE_I8,
    .acc_type = SYSARR_DTYPE_I32,
    .d_type = SYSARR_DTYPE_I8,
    .max_batch = 0,
};
#endif

static const sysarr_caps_t *sysarr_caps = &sysarr_truth_caps;

static int sysarr_load_caps(void) {
    return 0;
}

int sysarr_open(void) {
    return open("/dev/sysarr0", O_RDWR);
}

const sysarr_caps_t *sysarr_get_caps(void) {
    return sysarr_caps;
}

int sysarr_supports(sysarr_dtype_t a_type,
                    sysarr_dtype_t b_type,
                    sysarr_dtype_t acc_type,
                    sysarr_dtype_t d_type,
                    unsigned m) {
#if SYSARR_HW_MAC_T == SYSARR_HW_MACFP8INT8
    int int8_mode = a_type == SYSARR_DTYPE_I8 &&
                    b_type == SYSARR_DTYPE_I8 &&
                    acc_type == SYSARR_DTYPE_I32 &&
                    d_type == SYSARR_DTYPE_I8;
    int fp8_mode = a_type == SYSARR_DTYPE_FP8 &&
                   b_type == SYSARR_DTYPE_FP8 &&
                   acc_type == SYSARR_DTYPE_FP32 &&
                   d_type == SYSARR_DTYPE_FP8;
    return m == SYSARR_HW_M && (int8_mode || fp8_mode);
#else
    const sysarr_caps_t *caps = sysarr_get_caps();
    return caps->m == m &&
           caps->a_type == a_type &&
           caps->b_type == b_type &&
           caps->acc_type == acc_type &&
           caps->d_type == d_type;
#endif
}

int sysarr_submit(int fd, const sysarr_request_t *req) {
    return sysarr_submit_many(fd, req, 1);
}

int sysarr_submit_many(int fd, const sysarr_request_t *reqs, unsigned count) {
    unsigned bytes;
    sysarr_load_caps();
    if (!reqs || count == 0) return -1;
    if (count > sysarr_caps->max_batch) return -1;

    bytes = count * (unsigned)sizeof(sysarr_request_t);
    return write(fd, reqs, bytes) == (ssize_t)bytes ? 0 : -1;
}

int sysarr_wait(int fd) {
    return ioctl(fd, SYSARR_IOC_WAIT, 0) == 0 ? 0 : -1;
}

unsigned long long sysarr_last_cycles(int fd) {
    unsigned long long cycles = 0;
    return ioctl(fd, SYSARR_IOC_GET_LAST_CYCLES, &cycles) == 0 ? cycles : 0;
}

int sysarr_read_result(int fd, sysarr_result_t *result) {
    if (!result) return -1;
    if (sysarr_wait(fd) < 0) return -1;
    result->d[0] = 0;
    result->d[1] = 0;
    return 0;
}

unsigned sysarr_pack4_i8(sysarr_i8 b0, sysarr_i8 b1, sysarr_i8 b2, sysarr_i8 b3) {
    return ((unsigned)(unsigned char)b0) |
           ((unsigned)(unsigned char)b1 << 8) |
           ((unsigned)(unsigned char)b2 << 16) |
           ((unsigned)(unsigned char)b3 << 24);
}

sysarr_i8 sysarr_unpack_i8(unsigned word, unsigned byte) {
    return (sysarr_i8)((word >> (8 * byte)) & 0xffu);
}

void sysarr_pack_i8_tile(const sysarr_i8 src[SYSARR_MAX_M][SYSARR_MAX_M], sysarr_tile_t *dst) {
    for (unsigned r = 0; r < SYSARR_HW_M; r++) {
        dst->words[2 * r + 0] = sysarr_pack4_i8(src[r][0], src[r][1], src[r][2], src[r][3]);
        dst->words[2 * r + 1] = sysarr_pack4_i8(src[r][4], src[r][5], src[r][6], src[r][7]);
    }
}

void sysarr_unpack_i8_tile(const sysarr_tile_t *src, sysarr_i8 dst[SYSARR_MAX_M][SYSARR_MAX_M]) {
    for (unsigned r = 0; r < SYSARR_HW_M; r++) {
        for (unsigned c = 0; c < 4; c++) {
            dst[r][c] = sysarr_unpack_i8(src->words[2 * r + 0], c);
            dst[r][c + 4] = sysarr_unpack_i8(src->words[2 * r + 1], c);
        }
    }
}

void sysarr_pack_fp8_tile(const fp8_e4m3_t src[SYSARR_MAX_M][SYSARR_MAX_M],
                          sysarr_tile_t *dst) {
    for (unsigned r = 0; r < SYSARR_HW_M; r++) {
        dst->words[2 * r + 0] = sysarr_pack4_i8(
            (sysarr_i8)src[r][0], (sysarr_i8)src[r][1],
            (sysarr_i8)src[r][2], (sysarr_i8)src[r][3]);
        dst->words[2 * r + 1] = sysarr_pack4_i8(
            (sysarr_i8)src[r][4], (sysarr_i8)src[r][5],
            (sysarr_i8)src[r][6], (sysarr_i8)src[r][7]);
    }
}

void sysarr_unpack_fp8_tile(const sysarr_tile_t *src,
                            fp8_e4m3_t dst[SYSARR_MAX_M][SYSARR_MAX_M]) {
    for (unsigned r = 0; r < SYSARR_HW_M; r++) {
        for (unsigned c = 0; c < SYSARR_HW_M; c++) {
            unsigned word = src->words[2 * r + c / 4];
            dst[r][c] = (fp8_e4m3_t)(word >> (8 * (c % 4)));
        }
    }
}

void sysarr_make_chain_request(const void *a,
                               const void *b,
                               void *d,
                               unsigned chain_len,
                               sysarr_request_t *req) {
    (void)chain_len;
    sysarr_make_op_command(a, b, SYSARR_CMD_START_LAST, req);
    sysarr_make_wb_command(d, req + 1);
}

void sysarr_make_op_command(const void *a,
                            const void *b,
                            unsigned flags,
                            sysarr_request_t *req) {
    req->control = (SYSARR_CMD_TYPE_OP << 24) | ((flags & SYSARR_CMD_START_LAST) << 22);
    req->meta = 0;
    req->a_addr = (uintptr_t)a;
    req->b_addr = (uintptr_t)b;
    req->reserved = 0;
}

void sysarr_make_wb_command(void *d, sysarr_request_t *req) {
    req->control = SYSARR_CMD_TYPE_WB << 24;
    req->meta = 0;
    req->a_addr = (uintptr_t)d;
    req->b_addr = 0;
    req->reserved = 0;
}

int sysarr_make_dense_atb_command(const void *a,
                                  const void *b,
                                  unsigned a_tiles,
                                  unsigned b_tiles,
                                  sysarr_request_t *req) {
    unsigned max_tiles = SYSARR_HW_MAX_DENSE_MAT_SZ / SYSARR_HW_M;
    if (!req || !a || !b || a_tiles == 0 || b_tiles == 0 ||
        a_tiles > max_tiles || b_tiles > max_tiles) return -1;

    req->control = (SYSARR_CMD_TYPE_OP << 24) | (SYSARR_CMD_START_LAST << 22) | (1u << 21);
    req->meta = (a_tiles << 16) | b_tiles;
    req->b_addr = (uintptr_t)b;
    req->a_addr = (uintptr_t)a;
    req->reserved = 0;
    return 0;
}

void sysarr_make_dense_wb_command(void *d, sysarr_request_t *req) {
    req->control = (SYSARR_CMD_TYPE_WB << 24) | (1u << 23);
    req->meta = 0;
    req->a_addr = (uintptr_t)d;
    req->b_addr = 0;
    req->reserved = 0;
}

void sysarr_set_command_mac_type(sysarr_request_t *req, sysarr_mac_t mac_type) {
    req->control &= ~(3u << SYSARR_CMD_MAC_TYPE_SHIFT);
    req->control |= (unsigned)mac_type << SYSARR_CMD_MAC_TYPE_SHIFT;
}

int sysarr_atb_tile(int fd,
                    sysarr_dtype_t a_type,
                    sysarr_dtype_t b_type,
                    sysarr_dtype_t acc_type,
                    sysarr_dtype_t d_type,
                    const sysarr_tile_t *a,
                    const sysarr_tile_t *b,
                    sysarr_tile_t *d) {
    sysarr_request_t reqs[2];
    if (!sysarr_supports(a_type, b_type, acc_type, d_type, SYSARR_HW_M)) return -1;
    sysarr_make_op_command(a->words, b->words, SYSARR_CMD_START_LAST, &reqs[0]);
    sysarr_make_wb_command(d->words, &reqs[1]);
    sysarr_mac_t mac_type = a_type == SYSARR_DTYPE_FP8 ? SYSARR_MAC_FP8 : SYSARR_MAC_INT8;
    sysarr_set_command_mac_type(&reqs[0], mac_type);
    sysarr_set_command_mac_type(&reqs[1], mac_type);
    return sysarr_submit_many(fd, reqs, 2);
}

int sysarr_atb_tiles(int fd,
                     sysarr_dtype_t a_type,
                     sysarr_dtype_t b_type,
                     sysarr_dtype_t acc_type,
                     sysarr_dtype_t d_type,
                     const sysarr_tile_t *a_tiles,
                     const sysarr_tile_t *b_tiles,
                     sysarr_tile_t *d_tiles,
                     unsigned tile_count) {
    if (!sysarr_supports(a_type, b_type, acc_type, d_type, SYSARR_HW_M)) return -1;

    for (unsigned i = 0; i < tile_count; i++) {
        sysarr_request_t reqs[2];
        sysarr_make_op_command(a_tiles[i].words,
                                   b_tiles[i].words,
                                   SYSARR_CMD_START_LAST,
                                   &reqs[0]);
        sysarr_make_wb_command(d_tiles[i].words, &reqs[1]);
        sysarr_mac_t mac_type = a_type == SYSARR_DTYPE_FP8 ? SYSARR_MAC_FP8 : SYSARR_MAC_INT8;
        sysarr_set_command_mac_type(&reqs[0], mac_type);
        sysarr_set_command_mac_type(&reqs[1], mac_type);
        if (sysarr_submit_many(fd, reqs, 2) < 0) return -1;
    }

    return 0;
}
