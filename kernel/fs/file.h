#ifndef FILE_H
#define FILE_H

#include <stdint.h>
#include <stddef.h>

/* ── vnode types ─────────────────────────────────────────── */
#define VNODE_DEV    1   /* character device  */
#define VNODE_FILE   2   /* regular file      */
#define VNODE_DIR    3   /* directory         */
#define VNODE_PIPE   4   /* anonymous pipe    */

/* ── open flags ──────────────────────────────────────────── */
#define O_RDONLY  0x00
#define O_WRONLY  0x01
#define O_RDWR    0x02
#define O_CREAT   0x04
#define O_TRUNC   0x08
#define O_APPEND  0x10

/* ── fd limits ───────────────────────────────────────────── */
#define MAX_FDS     16
#define MAX_VNODES  32
#define MAX_DEVS     8

struct vnode;

/* ── vnode operations vtable ─────────────────────────────── */
typedef struct vnode_ops {
    int   (*open) (struct vnode *vn, int flags);
    int   (*close)(struct vnode *vn);
    int   (*read) (struct vnode *vn, void *buf, size_t n, uint32_t *pos);
    int   (*write)(struct vnode *vn, const void *buf, size_t n, uint32_t *pos);
    int   (*ioctl)(struct vnode *vn, uint32_t cmd, void *arg);
} vnode_ops_t;

/* ── vnode ───────────────────────────────────────────────── */
typedef struct vnode {
    uint32_t      type;
    vnode_ops_t  *ops;
    void         *data;       /* driver-private or inode ptr */
    uint32_t      refcount;
} vnode_t;

/* ── open file description ───────────────────────────────── */
typedef struct {
    vnode_t  *vnode;
    uint32_t  flags;
    uint32_t  pos;           /* byte offset (for files) */
    uint32_t  used;
} file_t;

/* ── global vnode table ──────────────────────────────────── */
extern vnode_t vnodes[MAX_VNODES];
extern uint32_t vnode_count;

vnode_t *vnode_alloc(uint32_t type, vnode_ops_t *ops, void *data);
void     vnode_free(vnode_t *vn);

/* ── per-process fd table (embedded in proc_t) ───────────── */
typedef struct files_struct {
    file_t files[MAX_FDS];
} fd_table_t;

/* fd table ops — called with proc's fd_table */
int  fd_alloc (fd_table_t *fdt, vnode_t *vn, int flags); /* returns fd */
void fd_free  (fd_table_t *fdt, int fd);
file_t *fd_get(fd_table_t *fdt, int fd);                 /* NULL if bad */
void fd_table_init(fd_table_t *fdt);
void fd_table_copy(fd_table_t *dst, const fd_table_t *src); /* for fork */

#endif
