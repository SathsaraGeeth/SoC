#ifndef BLOCKFS_H
#define BLOCKFS_H

#include "file.h"
#include <stdint.h>

#define BLOCKFS_NAME_MAX 32
#define BLOCKFS_TYPE_FILE 1
#define BLOCKFS_TYPE_DIR  2

void blockfs_init(void);
uint32_t blockfs_root(void);
int blockfs_resolve(uint32_t cwd, const char *path);
vnode_t *blockfs_open(const char *path, uint32_t cwd, int flags);
int blockfs_mkdir(const char *path, uint32_t cwd);
int blockfs_unlink(const char *path, uint32_t cwd);
int blockfs_rename(const char *old_path, const char *new_path, uint32_t cwd);
int blockfs_stat(const char *path, uint32_t cwd, uint32_t *size);
int blockfs_readdir(const char *path, uint32_t cwd, uint32_t index,
                    char *name, uint32_t *type, uint32_t *size);
void blockfs_getcwd(uint32_t inode, char *buf, int max);
int blockfs_chdir(const char *path, uint32_t cwd, uint32_t *inode);

#endif
