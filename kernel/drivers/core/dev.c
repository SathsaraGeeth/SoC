#include "dev.h"
#include "../../fs/vfs.h"
#include "../../lib/printk.h"
#include <stdint.h>

static dev_entry_t devtab[MAX_DEVS];
static uint32_t    dev_count = 0;

static void strcpy_d(char *dst, const char *src, int n) {
    int i = 0;
    while (i < n - 1 && src[i]) { dst[i] = src[i]; i++; }
    dst[i] = 0;
}

static int streq_d(const char *a, const char *b) {
    while (*a && *b) { if (*a != *b) return 0; a++; b++; }
    return *a == *b;
}

void dev_init(void) {
    dev_count = 0;
    for (int i = 0; i < MAX_DEVS; i++) devtab[i].used = 0;
    printk("[DEV] init ok\r\n");
}

int dev_register(const char *name, vnode_ops_t *ops, void *data) {
    if (dev_count >= MAX_DEVS) {
        printk("[DEV] table full\r\n");
        return -1;
    }

    vnode_t *vn = vnode_alloc(VNODE_DEV, ops, data);
    if (!vn) return -1;

    dev_entry_t *e = &devtab[dev_count++];
    strcpy_d(e->name, name, 16);
    e->vnode = vn;
    e->used  = 1;

    /* also plant under /dev/<name> in ramfs */
    vfs_register_dev(name, ops, data);

    printk("[DEV] registered /dev/%s\r\n", name);
    return 0;
}

vnode_t *dev_find(const char *name) {
    for (uint32_t i = 0; i < dev_count; i++)
        if (devtab[i].used && streq_d(devtab[i].name, name))
            return devtab[i].vnode;
    return 0;
}

int dev_name_at(uint32_t index, char *name, uint32_t max) {
    uint32_t visible = 0;

    for (uint32_t i = 0; i < dev_count; i++) {
        if (!devtab[i].used) continue;
        if (visible++ != index) continue;
        strcpy_d(name, devtab[i].name, (int)max);
        return 1;
    }

    return 0;
}

void dev_list(void) {
    printk("devices:\r\n");
    for (uint32_t i = 0; i < dev_count; i++) {
        if (devtab[i].used)
            printk("  /dev/%s\r\n", devtab[i].name);
    }
}
