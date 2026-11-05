#ifndef MM_MAPPING_H
#define MM_MAPPING_H

#include <stdint.h>
#include <stddef.h>
#include <soc.h>

typedef uintptr_t addr_t;

/*
 * A process owns a local virtual address range.  The most-significant mesh
 * coordinate bits are intentionally outside this range: user programs may
 * attach them with ADDR_MAKE() when addressing a peer region, while the VM
 * always indexes mappings by ADDR_OFFSET().  The remainder of the local
 * address space is reserved for MMIO and future kernel mappings.
 */
#define USER_VA_BASE       UINT64_C(0x0000000000010000)
#define USER_VA_LIMIT      UINT64_C(0x0000000100000000)
#define USER_MMAP_BASE     UINT64_C(0x0000000040000000)
#define USER_STACK_TOP     UINT64_C(0x0000000080000000)
#define USER_STACK_SIZE    PAGE_SIZE

static inline addr_t mapping_local_addr(addr_t addr) {
    return ADDR_OFFSET(addr);
}

static inline int mapping_user_range_valid(addr_t addr, size_t length) {
    addr_t local = mapping_local_addr(addr);
    if (length == 0 || local < USER_VA_BASE || local >= USER_VA_LIMIT)
        return 0;
    return length <= USER_VA_LIMIT - local;
}



// VMA permissions
#define PROT_READ  0x1
#define PROT_WRITE 0x2
#define PROT_EXEC  0x4

// VMA flags
#define MAP_SHARED  0x1
#define MAP_PRIVATE 0x2
#define MAP_FIXED   0x10
#define MAP_ANONYMOUS 0x20

#define MAX_VMAS 16

// Software page-table entry bits. Page-table pointers are at least
// 64-byte-aligned, so the low five bits are available for flags.
#define PTE_V 1
#define PTE_R 2
#define PTE_W 4
#define PTE_X 8
#define PTE_U 16
#define PTE_FLAGS_MASK ((uintptr_t)0x1F)

#define MAX_SW_PTES 256

typedef struct vma {
    addr_t vaddr_start;
    addr_t vaddr_end; // Exclusive; mesh bits are reserved by soc.h
    uint32_t prot;
    uint32_t flags;
    // For file-backed mappings
    int fd;
    addr_t offset;
    addr_t file_size; /* Bytes from this ELF segment that are present in the file. */
    int used;
} vma_t;

typedef uintptr_t pte_t;

typedef struct pte_slot {
    addr_t vpn_plus_one; /* zero marks a free slot */
    pte_t pte;
} pte_slot_t;

typedef struct mm {
    vma_t vmas[MAX_VMAS];
    pte_slot_t *page_map; // Sparse software map; hardware TLB is message-managed
    uintptr_t asid; // Hardware virtual-thread ID for this process
} mm_t;

vma_t *mapping_find_vma(mm_t *mm, addr_t addr);
int mapping_check_perm(vma_t *vma, uint32_t cause);
void mapping_fork_vma(mm_t *parent_mm, mm_t *child_mm, vma_t *vma);
void mapping_free_vma(mm_t *mm, vma_t *vma);

pte_t *mapping_get_pte(mm_t *mm, addr_t vpn, int alloc);
void mapping_map_page(mm_t *mm, addr_t vpn, addr_t pa, uint32_t prot, int is_user);
void mapping_activate(mm_t *mm);

#endif
