#include "blockfs.h"
#include "file.h"
#include "../mm/frame.h"
#include "../mm/page_msg.h"
#include "../lib/printk.h"
#include <soc.h>

#define BLOCKFS_MAGIC 0x53465332u /* SFS2 */
#define BLOCKFS_MAX_INODES 64
#define BLOCKFS_DATA_BASE  2
#define BLOCKFS_BLOCKS_PER_FILE 16
#define BLOCKFS_MAX_FILE_SIZE (BLOCKFS_BLOCKS_PER_FILE * PAGE_SIZE)

typedef struct {
    char name[BLOCKFS_NAME_MAX];
    uint32_t type;
    uint32_t parent;
    uint32_t size;
    uint32_t data_slot;
    uint32_t used;
} blockfs_inode_t;

typedef struct {
    uint32_t magic;
    uint32_t version;
    uint32_t inode_count;
    uint32_t next_slot;
    blockfs_inode_t inodes[BLOCKFS_MAX_INODES];
} blockfs_super_t;

static blockfs_super_t super;
static uint8_t io_page[PAGE_SIZE];
#define BLOCKFS_CACHE_PAGES 8
typedef struct { uint32_t page; int frame; uint32_t valid; } cache_entry_t;
static cache_entry_t cache[BLOCKFS_CACHE_PAGES];
static uint32_t cache_hand;

static int streq(const char *a, const char *b) {
    while (*a && *b && *a == *b) { a++; b++; }
    return *a == *b;
}

static void strcopy(char *dst, const char *src, int cap) {
    int i = 0; while (i + 1 < cap && src[i]) { dst[i] = src[i]; i++; } dst[i] = 0;
}

static uintptr_t fs_page(uint32_t page) { return FS_BASE_BA / PAGE_SIZE + page; }

static cache_entry_t *cache_page(uint32_t page) {
    for (uint32_t i = 0; i < BLOCKFS_CACHE_PAGES; i++)
        if (cache[i].valid && cache[i].page == page) return &cache[i];
    cache_entry_t *entry = &cache[cache_hand++ % BLOCKFS_CACHE_PAGES];
    if (entry->frame < 0) entry->frame = frame_alloc();
    if (entry->frame < 0) return 0;
    page_msg_load(fs_page(page), (uintptr_t)entry->frame);
    entry->page = page; entry->valid = 1;
    return entry;
}

static int transfer_page(uint32_t page, void *buffer, int store) {
    cache_entry_t *entry = cache_page(page);
    if (!entry) return -1;
    uint8_t *sram = (uint8_t *)(uintptr_t)(entry->frame << PAGE_SHIFT);
    if (store) {
        const uint8_t *src = (const uint8_t *)buffer;
        for (uint32_t i = 0; i < PAGE_SIZE; i++) sram[i] = src[i];
        page_msg_store(fs_page(page), (uintptr_t)entry->frame);
    } else {
        uint8_t *dst = (uint8_t *)buffer;
        for (uint32_t i = 0; i < PAGE_SIZE; i++) dst[i] = sram[i];
    }
    return 0;
}

static int sync_super(void) {
    const uint8_t *src = (const uint8_t *)&super;
    for (uint32_t i = 0; i < PAGE_SIZE; i++) io_page[i] = i < sizeof(super) ? src[i] : 0;
    return transfer_page(0, io_page, 1);
}

static int child_lookup(uint32_t parent, const char *name) {
    for (uint32_t i = 0; i < BLOCKFS_MAX_INODES; i++)
        if (super.inodes[i].used && super.inodes[i].parent == parent &&
            streq(super.inodes[i].name, name)) return (int)i;
    return -1;
}

int blockfs_resolve(uint32_t cwd, const char *path) {
    uint32_t current = path[0] == '/' ? 0 : cwd;
    if (path[0] == '/') path++;
    while (*path) {
        while (*path == '/') path++;
        if (!*path) break;
        char component[BLOCKFS_NAME_MAX]; int n = 0;
        while (*path && *path != '/') { if (n + 1 < BLOCKFS_NAME_MAX) component[n++] = *path; path++; }
        component[n] = 0;
        if (streq(component, ".")) continue;
        if (streq(component, "..")) { current = super.inodes[current].parent; continue; }
        int next = child_lookup(current, component);
        if (next < 0) return -1;
        current = (uint32_t)next;
    }
    return (int)current;
}

static int split_parent(const char *path, uint32_t cwd, uint32_t *parent, char *name) {
    char copy[128]; strcopy(copy, path, sizeof(copy));
    int last = -1; for (int i = 0; copy[i]; i++) if (copy[i] == '/') last = i;
    if (last < 0) { *parent = cwd; strcopy(name, copy, BLOCKFS_NAME_MAX); return *name ? 0 : -1; }
    strcopy(name, copy + last + 1, BLOCKFS_NAME_MAX);
    if (!*name) return -1;
    if (last == 0) *parent = 0;
    else { copy[last] = 0; int p = blockfs_resolve(cwd, copy); if (p < 0) return -1; *parent = p; }
    return super.inodes[*parent].type == BLOCKFS_TYPE_DIR ? 0 : -1;
}

static int alloc_inode(uint32_t parent, const char *name, uint32_t type) {
    if (child_lookup(parent, name) >= 0) return -1;
    for (uint32_t i = 1; i < BLOCKFS_MAX_INODES; i++) if (!super.inodes[i].used) {
        blockfs_inode_t *in = &super.inodes[i];
        strcopy(in->name, name, sizeof(in->name)); in->type = type; in->parent = parent;
        in->size = 0; in->used = 1;
        in->data_slot = type == BLOCKFS_TYPE_FILE ? super.next_slot++ : 0;
        if (i >= super.inode_count) super.inode_count = i + 1;
        return sync_super() < 0 ? -1 : (int)i;
    }
    return -1;
}

static int vn_open(vnode_t *vn, int flags) { (void)vn; (void)flags; return 0; }
static int vn_close(vnode_t *vn) { (void)vn; return 0; }

static int vn_read(vnode_t *vn, void *buf, size_t count, uint32_t *pos) {
    uint32_t idx = (uint32_t)(uintptr_t)vn->data;
    if (idx >= BLOCKFS_MAX_INODES || !super.inodes[idx].used) return -1;
    blockfs_inode_t *in = &super.inodes[idx];
    if (*pos >= in->size) return 0;
    if (count > in->size - *pos) count = in->size - *pos;
    uint8_t *out = (uint8_t *)buf; size_t done = 0;
    while (done < count) {
        uint32_t file_page = (*pos + done) / PAGE_SIZE, off = (*pos + done) & (PAGE_SIZE - 1);
        if (transfer_page(BLOCKFS_DATA_BASE + in->data_slot * BLOCKFS_BLOCKS_PER_FILE + file_page, io_page, 0) < 0) return -1;
        /* Demand-fault reads are page-sized.  Readahead those, but do not
         * double every small metadata/header read into a synchronous I/O. */
        if (count - done >= PAGE_SIZE &&
            file_page + 1 < (in->size + PAGE_SIZE - 1) / PAGE_SIZE)
            (void)cache_page(BLOCKFS_DATA_BASE + in->data_slot * BLOCKFS_BLOCKS_PER_FILE + file_page + 1);
        size_t chunk = PAGE_SIZE - off; if (chunk > count - done) chunk = count - done;
        for (size_t i = 0; i < chunk; i++) out[done + i] = io_page[off + i];
        done += chunk;
    }
    *pos += done; return (int)done;
}

static int vn_write(vnode_t *vn, const void *buf, size_t count, uint32_t *pos) {
    uint32_t idx = (uint32_t)(uintptr_t)vn->data;
    if (idx >= BLOCKFS_MAX_INODES || !super.inodes[idx].used || *pos + count > BLOCKFS_MAX_FILE_SIZE) return -1;
    blockfs_inode_t *in = &super.inodes[idx]; const uint8_t *input = (const uint8_t *)buf;
    size_t done = 0;
    while (done < count) {
        uint32_t file_page = (*pos + done) / PAGE_SIZE, off = (*pos + done) & (PAGE_SIZE - 1);
        uint32_t disk_page = BLOCKFS_DATA_BASE + in->data_slot * BLOCKFS_BLOCKS_PER_FILE + file_page;
        size_t chunk = PAGE_SIZE - off; if (chunk > count - done) chunk = count - done;
        if (off || chunk != PAGE_SIZE) transfer_page(disk_page, io_page, 0);
        else for (uint32_t i = 0; i < PAGE_SIZE; i++) io_page[i] = 0;
        for (size_t i = 0; i < chunk; i++) io_page[off + i] = input[done + i];
        if (transfer_page(disk_page, io_page, 1) < 0) return -1;
        done += chunk;
    }
    *pos += done; if (*pos > in->size) { in->size = *pos; sync_super(); }
    return (int)done;
}

static int vn_ioctl(vnode_t *vn, uint32_t cmd, void *arg) { (void)vn; (void)cmd; (void)arg; return -1; }
static vnode_ops_t file_ops = { vn_open, vn_close, vn_read, vn_write, vn_ioctl };

void blockfs_init(void) {
    cache_hand = 0;
    for (uint32_t i = 0; i < BLOCKFS_CACHE_PAGES; i++) {
        cache[i].valid = 0; cache[i].frame = -1; cache[i].page = 0;
    }
    if (transfer_page(0, io_page, 0) < 0) {
        printk("[PAGEFS] cannot read superblock\r\n"); return;
    }
    uint8_t *dst = (uint8_t *)&super;
    for (uint32_t i = 0; i < sizeof(super); i++) dst[i] = io_page[i];
    if (super.magic != BLOCKFS_MAGIC) {
        printk("[PAGEFS] invalid filesystem\r\n"); return;
    }
    printk("[PAGEFS] mounted root, %u inodes\r\n", super.inode_count);
}

uint32_t blockfs_root(void) { return 0; }

int blockfs_chdir(const char *path, uint32_t cwd, uint32_t *inode) {
    int idx = blockfs_resolve(cwd, path);
    if (idx < 0 || super.inodes[idx].type != BLOCKFS_TYPE_DIR) return -1;
    *inode = (uint32_t)idx;
    return 0;
}

vnode_t *blockfs_open(const char *path, uint32_t cwd, int flags) {
    int idx = blockfs_resolve(cwd, path);
    if (idx < 0 && (flags & O_CREAT)) {
        uint32_t parent; char name[BLOCKFS_NAME_MAX];
        if (split_parent(path, cwd, &parent, name) < 0) return 0;
        idx = alloc_inode(parent, name, BLOCKFS_TYPE_FILE);
    }
    if (idx < 0 || super.inodes[idx].type != BLOCKFS_TYPE_FILE) return 0;
    if (flags & O_TRUNC) { super.inodes[idx].size = 0; sync_super(); }
    return vnode_alloc(VNODE_FILE, &file_ops, (void *)(uintptr_t)idx);
}

int blockfs_mkdir(const char *path, uint32_t cwd) {
    uint32_t parent; char name[BLOCKFS_NAME_MAX];
    return split_parent(path, cwd, &parent, name) < 0 ? -1 :
        (alloc_inode(parent, name, BLOCKFS_TYPE_DIR) < 0 ? -1 : 0);
}

int blockfs_unlink(const char *path, uint32_t cwd) {
    int idx = blockfs_resolve(cwd, path); if (idx <= 0) return -1;
    if (super.inodes[idx].type == BLOCKFS_TYPE_DIR)
        for (uint32_t i = 0; i < BLOCKFS_MAX_INODES; i++)
            if (super.inodes[i].used && super.inodes[i].parent == (uint32_t)idx) return -1;
    super.inodes[idx].used = 0; return sync_super();
}

int blockfs_rename(const char *old_path, const char *new_path, uint32_t cwd) {
    int idx = blockfs_resolve(cwd, old_path); uint32_t parent; char name[BLOCKFS_NAME_MAX];
    if (idx <= 0 || split_parent(new_path, cwd, &parent, name) < 0 || child_lookup(parent, name) >= 0) return -1;
    super.inodes[idx].parent = parent; strcopy(super.inodes[idx].name, name, BLOCKFS_NAME_MAX);
    return sync_super();
}

int blockfs_stat(const char *path, uint32_t cwd, uint32_t *size) {
    int idx = blockfs_resolve(cwd, path); if (idx < 0) return -1;
    if (size) *size = super.inodes[idx].size; return 0;
}

int blockfs_readdir(const char *path, uint32_t cwd, uint32_t index, char *name, uint32_t *type, uint32_t *size) {
    int dir = blockfs_resolve(cwd, path); if (dir < 0 || super.inodes[dir].type != BLOCKFS_TYPE_DIR) return -1;
    uint32_t visible = 0;
    for (uint32_t i = 1; i < BLOCKFS_MAX_INODES; i++) if (super.inodes[i].used && super.inodes[i].parent == (uint32_t)dir) {
        if (visible++ != index) continue;
        strcopy(name, super.inodes[i].name, BLOCKFS_NAME_MAX);
        if (type) *type = super.inodes[i].type; if (size) *size = super.inodes[i].size; return 1;
    }
    return 0;
}

void blockfs_getcwd(uint32_t inode, char *buf, int max) {
    char reverse[128]; int pos = sizeof(reverse) - 1; reverse[pos] = 0;
    while (inode && pos > 1) {
        blockfs_inode_t *in = &super.inodes[inode]; int n = 0; while (in->name[n]) n++;
        pos -= n; for (int i = 0; i < n; i++) reverse[pos + i] = in->name[i]; reverse[--pos] = '/'; inode = in->parent;
    }
    if (!reverse[pos]) { buf[0] = '/'; buf[1] = 0; return; }
    int i = 0; while (reverse[pos] && i + 1 < max) buf[i++] = reverse[pos++]; buf[i] = 0;
}
