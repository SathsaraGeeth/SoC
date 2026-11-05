#include "vfs.h"
#include "blockfs.h"
#include "../drivers/core/dev.h"
#include "../proc/process.h"
#include "../lib/printk.h"

static int starts(const char *s, const char *prefix) {
    while (*prefix) if (*s++ != *prefix++) return 0;
    return 1;
}

static int streq(const char *a, const char *b) {
    while (*a && *b) {
        if (*a != *b) return 0;
        a++;
        b++;
    }
    return *a == *b;
}

static int is_dev_dir(const char *path, uint32_t cwd) {
    return streq(path, "/dev") || streq(path, "/dev/") ||
           (cwd == vfs_root() && streq(path, "dev"));
}

void vfs_init(void) {
    blockfs_init();
    printk("[VFS] page-engine root mounted\r\n");
}

uint32_t vfs_root(void) { return blockfs_root(); }

void vfs_register_dev(const char *name, vnode_ops_t *ops, void *data) {
    (void)name; (void)ops; (void)data;
}

vnode_t *vfs_open(const char *path, int flags) {
    if (starts(path, "/dev/")) return dev_find(path + 5);
    uint32_t cwd = current ? current->fs.cwd_inode : vfs_root();
    return blockfs_open(path, cwd, flags);
}

void vfs_getcwd(uint32_t inode, char *buf, int max) { blockfs_getcwd(inode, buf, max); }
int vfs_chdir(const char *path, uint32_t cwd, uint32_t *inode) { return blockfs_chdir(path, cwd, inode); }
int vfs_mkdir(const char *path, uint32_t cwd) { return blockfs_mkdir(path, cwd); }
int vfs_rm(const char *path, uint32_t cwd) { return blockfs_unlink(path, cwd); }
int vfs_stat(const char *path, uint32_t cwd, uint32_t *size) { return blockfs_stat(path, cwd, size); }
int vfs_rename(const char *old_path, const char *new_path, uint32_t cwd) { return blockfs_rename(old_path, new_path, cwd); }
int vfs_readdir(const char *path, uint32_t cwd, uint32_t index,
                char *name, uint32_t *type, uint32_t *size) {
    if (is_dev_dir(path, cwd)) {
        int result = dev_name_at(index, name, 32);
        if (result > 0) {
            if (type) *type = VNODE_DEV;
            if (size) *size = 0;
        }
        return result;
    }
    return blockfs_readdir(path, cwd, index, name, type, size);
}
