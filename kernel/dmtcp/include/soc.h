/* 
 * kernel/dmtcp/include/soc.h - definition of Topology, Physical Memory and MMIO of the SoC
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */


#ifndef SOC_H
#define SOC_H

#ifndef __ASSEMBLER__
#include <stdint.h>
#include <stddef.h>
#endif

/* Note: stdint.h and stddef.h are NOT included here because this header
 * is used in assembly files (via -x assembler-with-cpp), and the assembler
 * cannot parse C type definitions. Only include C headers in .c files. */

/* 
 * Topology:-
 * 1. The SoC is organized as a 2D checkerboard mesh of cluster (C) and memory (M).
 * 2. Each cluster is connected to up to 4 memory regions (N/S/E/W edges) and vise versa.
 * 3. Each cluster of cores can have some number of cores and each core can have some number of hw threads.
 * 4. Virtual (or global physical) address space in shared among the SoC.
 *      A) First 2n bits is the idx of the memory region. (N = 2^(2n) = #memory regions).
 *      B) First n bits is x - coord. and the next n bits is y - coord. of the memory region.
 *      C) [x_coord|y_coord| ... ]
 * 5. Examples:-
 *      A) 3*3    a)        b)
 *              C M C     M C M
 *              M C M     C M C
 *              C M C     M C M
 *      B) 5*5      a)            b)
 *              C M C M C     M C M C M
 *              M C M C M     C M C M C
 *              C M C M C     M C M C M
 *              M C M C M     C M C M C
 *              C M C M C     M C M C M
 *
 * 6. Reset vector geometry: Even X clusters boot from East, Odd X clusters boot from West.
 * 7. In software you only consider the thread id (dont have to consider the core id). the thread id is globaly unique.
 * 8. The thread id is calculated as follows.
 *      - offset = core_idx * threads_per_core + thread_idx
 *      - thread id:- [x_coord|y_coord|thread_id_offset]
 * 9. (row+col) even = cluster, odd = memory.
 */

#define NUM_REGIONS             1 /* generated from single_region */
#define NUM_CLUSTERS            1

/* address space */
#define VIR_ADDR_BITS           64
#define MESH_COORD_BITS         4
#define MESH_ADDR_BITS          (2 * MESH_COORD_BITS)
#define REGION_OFFSET_BITS      (VIR_ADDR_BITS - MESH_ADDR_BITS)
#ifdef __ASSEMBLER__
#define MESH_COORD_MASK         ((1 << MESH_COORD_BITS) - 1)
#define REGION_OFFSET_MASK      (~0 >> MESH_ADDR_BITS)
#else
#define MESH_COORD_MASK         ((UINT64_C(1) << MESH_COORD_BITS) - UINT64_C(1))
#define REGION_OFFSET_MASK      (UINT64_MAX >> MESH_ADDR_BITS)
/* Mesh coordinates occupy the high MESH_ADDR_BITS of every global address.
 * Kernel memory code must keep them intact while operating on a local offset. */
#define ADDR_ROW(addr)          ((((uint64_t)(addr)) >> (REGION_OFFSET_BITS + MESH_COORD_BITS)) & MESH_COORD_MASK)
#define ADDR_COL(addr)          ((((uint64_t)(addr)) >> REGION_OFFSET_BITS) & MESH_COORD_MASK)
#define ADDR_OFFSET(addr)       (((uint64_t)(addr)) & REGION_OFFSET_MASK)
#define ADDR_MAKE(row, col, offset) \
    ((((uint64_t)(row) & MESH_COORD_MASK) << (REGION_OFFSET_BITS + MESH_COORD_BITS)) | \
     (((uint64_t)(col) & MESH_COORD_MASK) << REGION_OFFSET_BITS) | \
     ((uint64_t)(offset) & REGION_OFFSET_MASK))
#define ADDR_RETAIN_MESH(addr, local_offset) \
    ((uint64_t)(addr) & ~REGION_OFFSET_MASK) | ((uint64_t)(local_offset) & REGION_OFFSET_MASK)
#endif

/* thread id */
#define SYS_CORES_PER_CLUSTER   1
#define SYS_ARRAY_MAC20I        0
#define SYS_ARRAY_MACFP8        1
#define SYS_ARRAY_MACFP8INT8     2
#define SYS_ARRAY_MAC_T         SYS_ARRAY_MACFP8INT8
#define SYS_ARRAY_M             8
#define SYS_ARRAY_MAX_DENSE_MAT_SZ 256
#define THREADS_IN_CLUSTER      8
#define THREAD_OFFSET_BITS      3 /* ceil(log2(THREADS_IN_CLUSTER)) */
#define THREAD_OFFSET_MASK      ((1 << THREAD_OFFSET_BITS) - 1)
#define CLOCK_FREQ_HZ           1000000000
#define IPI_VECTOR_WORD_BITS    (ARCH_WORD_SIZE * 8)
#define IPI_VECTOR_WORDS        ALIGN_UP(THREADS_IN_CLUSTER, IPI_VECTOR_WORD_BITS) / IPI_VECTOR_WORD_BITS
#define IPI_VECTOR_WORD_MASK(w) \
    ((((w) + 1) * IPI_VECTOR_WORD_BITS) <= THREADS_IN_CLUSTER ? ~(uintptr_t)0 : (((uintptr_t)1 << (THREADS_IN_CLUSTER - ((w) * IPI_VECTOR_WORD_BITS))) - 1))
#define THREADS_SECONDARY_MASK_WORD(w, boot_tid) \
    (IPI_VECTOR_WORD_MASK(w) & (((boot_tid) / IPI_VECTOR_WORD_BITS) == (w) ? ~((uintptr_t)1 << ((boot_tid) % IPI_VECTOR_WORD_BITS)) : ~(uintptr_t)0))

#define THREAD_ROW(tid)         (((tid) >> (THREAD_OFFSET_BITS + MESH_COORD_BITS)) & MESH_COORD_MASK)
#define THREAD_COL(tid)         (((tid) >>  THREAD_OFFSET_BITS) & MESH_COORD_MASK)
#define THREAD_OFFSET(tid)      ((tid)  & THREAD_OFFSET_MASK)

/* locality check */
#define IS_LOCAL(tid, addr)     \
    ((abs((int)ADDR_ROW(addr) - (int)THREAD_ROW(tid)) + \
      abs((int)ADDR_COL(addr) - (int)THREAD_COL(tid))) == 1)


/* 
 * Local structure of a memory region:-
 * 1. Physical Memory and MMIO
 * 2. Following are physical addresses in that local region - in global context they get an offset as discussed above.
 * 3. Each region has a RAM and a ROM. Also a secondary block device. (e.g. page accessible dram or flash).
 * 4. The secondary device is accessible through the memory node using page engine (which in the later stages also used to implement virtual memory).
 * 5. Only the cluster 0 get a uart0 if others need it have to come through the mesh in software.
 */
#define ARCH_WORD_SIZE          8
#define PAGE_SHIFT              12
#define PAGE_SIZE               (1 << PAGE_SHIFT)                       /* 4KB */
#define BLOCK_SIZE              PAGE_SIZE
#define ALIGN_UP(x, a)          (((x) + ((a) - 1)) & ~((a) - 1))

#define ROM_BASE                0x00000000
#define ROM_SIZE                0x00004000                              /* 16KB */
#define ROM_END                 (ROM_BASE + ROM_SIZE)
#define RAM_BASE                ROM_END
// #define REGION_SIZE             (1 << REGION_OFFSET_BITS)               /* ? */
#define REGION_SIZE             0x00200000                              /* 2MB */
#define RAM_SIZE                (REGION_SIZE - ROM_SIZE - MMIO_SIZE)
#define RAM_END                 (RAM_BASE + RAM_SIZE)

#define MMIO_SIZE               0x00080000                              /* 512KB */
#define MMIO_BASE               (REGION_SIZE - MMIO_SIZE)
#define UART_BASE               UINT64_C(0x0000001000000000)
#define UART_SIZE               UINT64_C(0x0000000000001000)            /* 4KB */
#define IPI_BASE                UINT64_C(0x0000001000001000)
#define IPI_SIZE                UINT64_C(0x0000000000001000)            /* 4KB */
#define IPI_REG                 IPI_BASE                                /* Inter-cluster RV64 vector window */
#define IPI_END                 (IPI_BASE + IPI_SIZE)
#define SYS_MMIO_BASE           UINT64_C(0x0000001001000000)
#define SYS_MMIO_SIZE           UINT64_C(0x0000000000001000)
#define TIMER_MMIO_BASE         UINT64_C(0x0000001002000000)
#define TIMER_MMIO_SIZE         UINT64_C(0x0000000001000000)
#define FRAMEBUFFER_BASE         UINT64_C(0x0000000000100000) /* region-0 SRAM */
#define FRAMEBUFFER_WIDTH        32u
#define FRAMEBUFFER_HEIGHT       32u
#define FRAMEBUFFER_BPP          1u
#define FRAMEBUFFER_SIZE         (FRAMEBUFFER_WIDTH * FRAMEBUFFER_HEIGHT * FRAMEBUFFER_BPP)
#define HOST_CONSOLE_BASE        UINT64_C(0x0000000000101000) /* /dev/fb1 SRAM ring */
#define HOST_CONSOLE_SIZE        4096u

#ifndef __ASSEMBLER__
typedef struct ap_mailbox {
    uintptr_t entry_fn;
    uintptr_t release_flag;
    uintptr_t stack_ptr;
} ap_mailbox_t;

typedef struct smp_mailbox {
    ap_mailbox_t ap[THREADS_IN_CLUSTER];
} smp_mailbox_t;

#define SMP_MAILBOX ((volatile smp_mailbox_t *)BL2_SMP_MAILBOX_BASE)

static inline void ipi_trigger_word(uint32_t word, uintptr_t vector) {
    *(volatile uintptr_t *)(uintptr_t)(IPI_BASE + (uintptr_t)word * ARCH_WORD_SIZE) = vector;
}

static inline void ipi_trigger_secondary(uint32_t boot_tid) {
    for (uint32_t word = 0; word < IPI_VECTOR_WORDS; word++) {
        ipi_trigger_word(word, THREADS_SECONDARY_MASK_WORD(word, boot_tid));
    }
}

static inline void ipi_trigger_target(uint32_t target_tid) {
    uint32_t local_tid = THREAD_OFFSET(target_tid);
    uint32_t word = local_tid / IPI_VECTOR_WORD_BITS;
    uintptr_t vector = (uintptr_t)1 << (local_tid % IPI_VECTOR_WORD_BITS);
    ipi_trigger_word(word, vector);
}

static inline uint32_t get_my_region_id(uint32_t tid) {
    uint32_t cx = THREAD_COL(tid);
    uint32_t cy = THREAD_ROW(tid);
    uint32_t mx = (cx % 2 == 0) ? (cx + 1) : (cx - 1);
    uint32_t my = cy;
    
    return (my * 4 + mx) / 2;
}

static inline uint64_t get_region_base(uint32_t region_id) {
    uint32_t y = region_id / 2;
    uint32_t x = (region_id % 2) * 2 + (1 - (y % 2));
    return ADDR_MAKE(y, x, 0);
}
#endif


/*  early memory management */
/* for all regions */
#define BL1_BASE                ROM_END
#define BL1_THREAD_STACK_SIZE   PAGE_SIZE
#define BL1_THREAD_STACK_SHIFT  PAGE_SHIFT
#define BL1_SIZE                ALIGN_UP(THREADS_IN_CLUSTER * BL1_THREAD_STACK_SIZE, PAGE_SIZE)
/* only for region 0 */
#define BL2_BASE                (BL1_BASE + BL1_SIZE)
#define BL2_SIZE                0x00008000                              /* 32KB */
#define BL2A_SIZE               0x00008000                              /* 32KB */
#define BL2_HEAP_BASE           (BL2_BASE + BL2_SIZE)
#define BL2_SMP_STACK_SIZE      (PAGE_SIZE / 4)
#define BL2_HEAP_SIZE           ALIGN_UP(THREADS_IN_CLUSTER * BL2_SMP_STACK_SIZE, PAGE_SIZE)
/* for all regions */
#define BL2_SMP_MAILBOX_BASE    (BL2_HEAP_BASE + BL2_HEAP_SIZE)
#define BL2_SMP_MAILBOX_ENTRY_SIZE (3 * ARCH_WORD_SIZE)
#define BL2_SMP_MAILBOX_SIZE    ALIGN_UP(THREADS_IN_CLUSTER * BL2_SMP_MAILBOX_ENTRY_SIZE, PAGE_SIZE)
#define KERNEL_BASE             (BL2_SMP_MAILBOX_BASE + BL2_SMP_MAILBOX_SIZE)
#define KERNEL_SIZE             0x00080000                              /* 512KB */
#define KERNEL_HEAP_SIZE        (128 * 1024)
#define KERNEL_SMP_STACK_SIZE   PAGE_SIZE


/* 
 * Block Device:-
 * 1. Block Size = Page Size
 * 2. Provide presistance
 * 3. Acessed through the page_engine
 * 4. LBA is also global like memory addresses. [x_coord|y_coord| ... ] owned by a memory region.
 * 5. Currently only region0 has block storage, but still we share through memory mesh.
 */

#define BL2_BASE_BA             0x20010000
#define BL2A_BASE_BA            (BL2_BASE_BA + BL2_SIZE)
#define KERNEL_BASE_BA          (BL2A_BASE_BA + BL2A_SIZE)
#define KERNEL_SIZE             0x00080000                              /* 512KB */
#define FS_BASE_BA              0x20098000
#define FS_SIZE                 0x00100000                              /* 1MB */


#endif /* SOC_H */
