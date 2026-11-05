#include "file.h"
#include "../lib/printk.h"
#include <stdint.h>

/* ── global vnode table ──────────────────────────────────── */
vnode_t  vnodes[MAX_VNODES];
uint32_t vnode_count = 0;

vnode_t *vnode_alloc(uint32_t type, vnode_ops_t *ops, void *data) {
    for (uint32_t i = 0; i < MAX_VNODES; i++) {
        if (vnodes[i].refcount == 0) {
            vnodes[i].type     = type;
            vnodes[i].ops      = ops;
            vnodes[i].data     = data;
            vnodes[i].refcount = 1;
            return &vnodes[i];
        }
    }
    printk("[VFS] vnode table full\r\n");
    return 0;
}

void vnode_free(vnode_t *vn) {
    if (!vn) return;
    if (vn->refcount > 0) vn->refcount--;
}

/* ── fd table ────────────────────────────────────────────── */
void fd_table_init(fd_table_t *fdt) {
    for (int i = 0; i < MAX_FDS; i++)
        fdt->files[i].used = 0;
}

/* copy fd table for fork — increments vnode refcounts */
void fd_table_copy(fd_table_t *dst, const fd_table_t *src) {
    for (int i = 0; i < MAX_FDS; i++) {
        dst->files[i] = src->files[i];
        if (src->files[i].used && src->files[i].vnode) {
            src->files[i].vnode->refcount++;
            if (src->files[i].vnode->ops && src->files[i].vnode->ops->open)
                src->files[i].vnode->ops->open(src->files[i].vnode,
                                               (int)src->files[i].flags);
        }
    }
}

/* allocate lowest free fd */
int fd_alloc(fd_table_t *fdt, vnode_t *vn, int flags) {
    for (int i = 0; i < MAX_FDS; i++) {
        if (!fdt->files[i].used) {
            fdt->files[i].vnode = vn;
            fdt->files[i].flags = (uint32_t)flags;
            fdt->files[i].pos   = 0;
            fdt->files[i].used  = 1;
            return i;
        }
    }
    printk("[VFS] fd table full\r\n");
    return -1;
}

void fd_free(fd_table_t *fdt, int fd) {
    if (fd < 0 || fd >= MAX_FDS) return;
    file_t *f = &fdt->files[fd];
    if (!f->used) return;
    if (f->vnode) {
        if (f->vnode->ops && f->vnode->ops->close)
            f->vnode->ops->close(f->vnode);
        vnode_free(f->vnode);
    }
    f->used  = 0;
    f->vnode = 0;
}

file_t *fd_get(fd_table_t *fdt, int fd) {
    if (fd < 0 || fd >= MAX_FDS) return 0;
    if (!fdt->files[fd].used)    return 0;
    return &fdt->files[fd];
}
