#ifndef VFS_H
#define VFS_H

#include "file.h"
#include <stdint.h>

void vfs_init(void);
vnode_t *vfs_open(const char *path, int flags);
void vfs_register_dev(const char *name, vnode_ops_t *ops, void *data);
void vfs_getcwd(uint32_t inode, char *buf, int max);
int vfs_chdir(const char *path, uint32_t cwd, uint32_t *inode);
uint32_t vfs_root(void);
int vfs_mkdir(const char *path, uint32_t cwd);
int vfs_rm(const char *path, uint32_t cwd);
int vfs_stat(const char *path, uint32_t cwd, uint32_t *size);
int vfs_rename(const char *old_path, const char *new_path, uint32_t cwd);
int vfs_readdir(const char *path, uint32_t cwd, uint32_t index,
                char *name, uint32_t *type, uint32_t *size);

#endif
