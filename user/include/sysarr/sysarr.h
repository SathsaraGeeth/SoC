#ifndef DMCTP_SYSARR_H
#define DMCTP_SYSARR_H

#include <sys/types.h>
#include <stdint.h>
#include <math/fp8.h>
#include <sysarr/config.h>

#define SYSARR_IOC_GET_CAPS 0x7301u
#define SYSARR_IOC_WAIT 0x7302u
#define SYSARR_IOC_GET_LAST_CYCLES 0x7303u
#define SYSARR_MAX_M 8
#define SYSARR_WORDS_PER_TILE 16
#define SYSARR_VECTOR_ALIGNMENT 8
#define SYSARR_CMD_MID 0x00u
#define SYSARR_CMD_START 0x01u
#define SYSARR_CMD_LAST 0x02u
#define SYSARR_CMD_START_LAST 0x03u
#define SYSARR_CMD_WB 0x04u
#define SYSARR_CMD_DENSE_MID 0x10u
#define SYSARR_CMD_DENSE_START 0x11u
#define SYSARR_CMD_DENSE_LAST 0x12u
#define SYSARR_CMD_DENSE_START_LAST 0x13u
#define SYSARR_CMD_DENSE_WB 0x14u

#define SYSARR_CMD_TYPE_OP 0x01u
#define SYSARR_CMD_TYPE_WB 0x02u
#define SYSARR_CMD_TYPE_DELEGATION 0x03u
#define SYSARR_CMD_TYPE_RELEASE 0x04u
#define SYSARR_CMD_MAC_TYPE_SHIFT 19u

typedef signed char sysarr_i8;

typedef enum {
    SYSARR_DTYPE_I8,
    SYSARR_DTYPE_I32,
    SYSARR_DTYPE_FP8,
    SYSARR_DTYPE_FP32,
} sysarr_dtype_t;

typedef enum {
    SYSARR_MAC_INT8,
    SYSARR_MAC_FP8,
} sysarr_mac_t;

typedef struct {
    unsigned m;
    sysarr_dtype_t a_type;
    sysarr_dtype_t b_type;
    sysarr_dtype_t acc_type;
    sysarr_dtype_t d_type;
    unsigned max_batch;
} sysarr_caps_t;

typedef struct {
    unsigned control;
    unsigned meta;
    uintptr_t a_addr;
    uintptr_t b_addr;
    uintptr_t reserved;
} sysarr_request_t;

typedef struct {
    unsigned d[2];
} sysarr_result_t;

typedef struct __attribute__((aligned(SYSARR_VECTOR_ALIGNMENT))) {
    unsigned words[SYSARR_WORDS_PER_TILE];
} sysarr_tile_t;

int sysarr_open(void);
const sysarr_caps_t *sysarr_get_caps(void);
int sysarr_supports(sysarr_dtype_t a_type,
                    sysarr_dtype_t b_type,
                    sysarr_dtype_t acc_type,
                    sysarr_dtype_t d_type,
                    unsigned m);
int sysarr_submit(int fd, const sysarr_request_t *req);
int sysarr_submit_many(int fd, const sysarr_request_t *reqs, unsigned count);
int sysarr_wait(int fd);
unsigned long long sysarr_last_cycles(int fd);
int sysarr_read_result(int fd, sysarr_result_t *result);

unsigned sysarr_pack4_i8(sysarr_i8 b0, sysarr_i8 b1, sysarr_i8 b2, sysarr_i8 b3);
sysarr_i8 sysarr_unpack_i8(unsigned word, unsigned byte);
void sysarr_pack_i8_tile(const sysarr_i8 src[SYSARR_MAX_M][SYSARR_MAX_M], sysarr_tile_t *dst);
void sysarr_unpack_i8_tile(const sysarr_tile_t *src, sysarr_i8 dst[SYSARR_MAX_M][SYSARR_MAX_M]);
void sysarr_pack_fp8_tile(const fp8_e4m3_t src[SYSARR_MAX_M][SYSARR_MAX_M],
                          sysarr_tile_t *dst);
void sysarr_unpack_fp8_tile(const sysarr_tile_t *src,
                            fp8_e4m3_t dst[SYSARR_MAX_M][SYSARR_MAX_M]);

void sysarr_make_chain_request(const void *a,
                               const void *b,
                               void *d,
                               unsigned chain_len,
                               sysarr_request_t *req);
void sysarr_make_op_command(const void *a,
                            const void *b,
                            unsigned flags,
                            sysarr_request_t *req);
void sysarr_make_wb_command(void *d, sysarr_request_t *req);
int sysarr_make_dense_atb_command(const void *a,
                                  const void *b,
                                  unsigned a_tiles,
                                  unsigned b_tiles,
                                  sysarr_request_t *req);
void sysarr_make_dense_wb_command(void *d, sysarr_request_t *req);
void sysarr_set_command_mac_type(sysarr_request_t *req, sysarr_mac_t mac_type);
int sysarr_atb_tile(int fd,
                    sysarr_dtype_t a_type,
                    sysarr_dtype_t b_type,
                    sysarr_dtype_t acc_type,
                    sysarr_dtype_t d_type,
                    const sysarr_tile_t *a,
                    const sysarr_tile_t *b,
                    sysarr_tile_t *d);
int sysarr_atb_tiles(int fd,
                     sysarr_dtype_t a_type,
                     sysarr_dtype_t b_type,
                     sysarr_dtype_t acc_type,
                     sysarr_dtype_t d_type,
                     const sysarr_tile_t *a_tiles,
                     const sysarr_tile_t *b_tiles,
                     sysarr_tile_t *d_tiles,
                     unsigned tile_count);

#endif
