#include "sys_array_dev.h"
#include "../core/dev.h"
#include "../../lib/printk.h"
#include "../../include/mmio.h"
#include "../../dmtcp/include/soc.h"
#include "../../dmtcp/include/regs.h"
#include <stdint.h>
#include <stddef.h>

#define SYS_ARRAY_STATUS            (SYS_MMIO_BASE + UINT64_C(0x00))
#define SYS_ARRAY_CMD               (SYS_MMIO_BASE + UINT64_C(0x08))
#define SYS_ARRAY_LAST_CYCLES       (SYS_MMIO_BASE + UINT64_C(0x10))

#define SYS_ARRAY_STATUS_NONEMPTY   (1u << 3)
#define SYS_ARRAY_STATUS_FULL       (1u << 4)
#define SYS_ARRAY_STATUS_EMPTY      (1u << 5)
#define SYS_ARRAY_STATUS_ENQ_READY  (1u << 6)
#define SYS_ARRAY_STATUS_DELEGATED  (1u << 7)
#define SYS_ARRAY_POLL_LIMIT        262144u

#define SYSARR_IOC_GET_CAPS         0x7301u
#define SYSARR_IOC_WAIT             0x7302u
#define SYSARR_IOC_GET_LAST_CYCLES  0x7303u

#define SYSARR_CMD_TYPE_OP           0x01u
#define SYSARR_CMD_TYPE_WRITE_BACK   0x02u
#define SYSARR_CMD_TYPE_DELEGATION   0x03u
#define SYSARR_CMD_TYPE_RELEASE      0x04u
#define SYSARR_CMD_MAC_TYPE_SHIFT    19u

enum {
    SYSARR_DTYPE_I8,
    SYSARR_DTYPE_I32,
    SYSARR_DTYPE_FP8,
    SYSARR_DTYPE_FP32,
};

typedef struct {
    uint32_t control;
    uint32_t meta;
    uintptr_t a_addr;
    uintptr_t b_addr;
    uintptr_t reserved;
} sys_array_command_t;

typedef struct {
    uint32_t m;
    uint32_t a_type;
    uint32_t b_type;
    uint32_t acc_type;
    uint32_t d_type;
    uint32_t max_batch;
} sys_array_caps_t;

static const sys_array_caps_t sys_array_caps = {
    .m = SYS_ARRAY_M,
#if SYS_ARRAY_MAC_T == SYS_ARRAY_MAC20I || \
    SYS_ARRAY_MAC_T == SYS_ARRAY_MACFP8INT8
    .a_type = SYSARR_DTYPE_I8,
    .b_type = SYSARR_DTYPE_I8,
    .acc_type = SYSARR_DTYPE_I32,
    .d_type = SYSARR_DTYPE_I8,
#elif SYS_ARRAY_MAC_T == SYS_ARRAY_MACFP8
    .a_type = SYSARR_DTYPE_FP8,
    .b_type = SYSARR_DTYPE_FP8,
    .acc_type = SYSARR_DTYPE_FP32,
    .d_type = SYSARR_DTYPE_FP8,
#else
    .a_type = 0xffffffffu,
    .b_type = 0xffffffffu,
    .acc_type = 0xffffffffu,
    .d_type = 0xffffffffu,
#endif
    .max_batch = 8192,
};

static uint32_t sys_array_opcode(const sys_array_command_t *cmd) {
    return cmd->control >> 24;
}

static int sys_array_dense_dimensions_valid(const sys_array_command_t *cmd) {
    uint32_t a_tiles = cmd->meta >> 16;
    uint32_t b_tiles = cmd->meta & 0xffffu;
    uint32_t max_tiles = SYS_ARRAY_MAX_DENSE_MAT_SZ / SYS_ARRAY_M;

    return a_tiles != 0 && b_tiles != 0 &&
           a_tiles <= max_tiles && b_tiles <= max_tiles;
}

static int sys_array_is_payload(const sys_array_command_t *cmd) {
    uint32_t mac_type = (cmd->control >> SYSARR_CMD_MAC_TYPE_SHIFT) & 3u;
    if (mac_type > 1u) return 0;

    switch (sys_array_opcode(cmd)) {
    case SYSARR_CMD_TYPE_OP:
        if ((cmd->control & 0x0007ffffu) != 0) return 0;
        return (cmd->control & (1u << 21)) ? sys_array_dense_dimensions_valid(cmd) : 1;
    case SYSARR_CMD_TYPE_WRITE_BACK:
        return (cmd->control & 0x0067ffffu) == 0;
    default:
        return 0;
    }
}

static int sys_array_wait_available(void) {
    uint32_t first = reg32_read(SYS_ARRAY_STATUS);
    for (uint32_t i = 0; i < SYS_ARRAY_POLL_LIMIT; i++) {
        uint32_t status = reg32_read(SYS_ARRAY_STATUS);
        if ((status & (SYS_ARRAY_STATUS_DELEGATED | SYS_ARRAY_STATUS_NONEMPTY)) == 0) {
            return 0;
        }
        wfi();
    }
    return -1;
}

static void sys_array_post(const sys_array_command_t *cmd) {
    uint64_t header = ((uint64_t)cmd->meta << 32) | cmd->control;
    reg64_write(SYS_ARRAY_CMD, header);
    reg64_write(SYS_ARRAY_CMD, cmd->a_addr);
    reg64_write(SYS_ARRAY_CMD, cmd->b_addr);
    reg64_write(SYS_ARRAY_CMD, cmd->reserved);
}

static sys_array_command_t sys_array_control(uint32_t opcode,
                                              uint32_t meta,
                                              uintptr_t a_addr,
                                              uintptr_t b_addr) {
    sys_array_command_t cmd;
    cmd.control = opcode << 24;
    cmd.meta = meta;
    cmd.b_addr = b_addr;
    cmd.a_addr = a_addr;
    cmd.reserved = 0;
    return cmd;
}

static void sys_array_post_release(uintptr_t vtid) {
    sys_array_command_t release = sys_array_control(SYSARR_CMD_TYPE_RELEASE, 0, vtid, 0);
    sys_array_post(&release);
}

static int sys_array_open(vnode_t *vn, int flags) {
    (void)vn;
    (void)flags;
    return 0;
}

static int sys_array_close(vnode_t *vn) {
    (void)vn;
    return 0;
}

static int sys_array_write(vnode_t *vn, const void *buf, size_t n, uint32_t *pos) {
    (void)vn;
    (void)pos;

    if (!buf || n == 0 || (n % sizeof(sys_array_command_t)) != 0) return -1;

    const sys_array_command_t *cmds = (const sys_array_command_t *)buf;
    size_t count = n / sizeof(sys_array_command_t);
    if (count > sys_array_caps.max_batch) return -1;
    for (size_t i = 0; i < count; i++) {
        if (!sys_array_is_payload(&cmds[i])) return -1;
    }

    uintptr_t tid = csr_read(CSR_THREAD_ID);
    uintptr_t vtid = csr_read(CSR_VIRTUAL_THRD_ID);
    printk("[SYSARR] submit cmds=%d tid=%d vtid=%d\r\n", count, tid, vtid);
    sys_array_command_t delegation = sys_array_control(SYSARR_CMD_TYPE_DELEGATION,
                                                        0, vtid, tid);
    sys_array_post(&delegation);

    for (size_t i = 0; i < count; i++) {
        sys_array_post(&cmds[i]);
    }

    sys_array_post_release(vtid);
    printk("[SYSARR] queued release\r\n");
    return (int)n;
}

static int sys_array_read(vnode_t *vn, void *buf, size_t n, uint32_t *pos) {
    (void)vn;
    (void)buf;
    (void)n;
    (void)pos;
    return -1;
}

static int sys_array_ioctl(vnode_t *vn, uint32_t cmd, void *arg) {
    (void)vn;
    if (cmd == SYSARR_IOC_GET_CAPS && arg) {
        *(sys_array_caps_t *)arg = sys_array_caps;
        return 0;
    }
    if (cmd == SYSARR_IOC_WAIT) {
        printk("[SYSARR] wait\r\n");
        int ret = sys_array_wait_available();
        printk("[SYSARR] wait ret=%d\r\n", ret);
        return ret;
    }
    if (cmd == SYSARR_IOC_GET_LAST_CYCLES && arg) {
        *(uint64_t *)arg = reg64_read(SYS_ARRAY_LAST_CYCLES);
        return 0;
    }
    return -1;
}

static vnode_ops_t sys_array_vnode_ops = {
    .open  = sys_array_open,
    .close = sys_array_close,
    .read  = sys_array_read,
    .write = sys_array_write,
    .ioctl = sys_array_ioctl,
};

void sys_array_dev_init(void) {
    dev_register("sysarr0", &sys_array_vnode_ops, 0);
    printk("[SYSARR] command stream ready\r\n");
}
