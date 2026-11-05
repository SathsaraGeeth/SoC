 #ifndef REGS_H
#define REGS_H

#ifndef __ASSEMBLER__
#include <stdint.h>

/* RV64 IPI MMIO access: each vector word is an XLEN-wide register. */
#define IPI_MMIO_WORD(addr) (*(volatile uintptr_t *)(uintptr_t)(addr))

/* ------------------------------------------------------------------ */
/* CSR access macros                                                   */
/* ------------------------------------------------------------------ */

#define csr_read(reg) \
    ({ uintptr_t __v; asm volatile("csrr %0, %1" : "=r"(__v) : "i"(reg)); __v; })

#define csr_write(reg, val) \
    asm volatile("csrw %0, %1" :: "i"(reg), "r"((uintptr_t)(val)))

#define csr_set(reg, bits) \
    asm volatile("csrs %0, %1" :: "i"(reg), "r"((uintptr_t)(bits)))

#define csr_clear(reg, bits) \
    asm volatile("csrc %0, %1" :: "i"(reg), "r"((uintptr_t)(bits)))

static inline uint32_t load_reserved(volatile uint32_t *addr) {
    uint32_t val;
#ifdef DMCTP_RISCV_COMPAT
    asm volatile("lr.w %0, (%1)" : "=r"(val) : "r"(addr) : "memory");
#else
    asm volatile("LOAD.i32.res %0, %1" : "=r"(val) : "r"(addr) : "memory");
#endif
    return val;
}

static inline uint32_t store_conditional(volatile uint32_t *addr, uint32_t val) {
    uint32_t ret;
#ifdef DMCTP_RISCV_COMPAT
    asm volatile("sc.w %0, %1, (%2)" : "=r"(ret) : "r"(val), "r"(addr) : "memory");
#else
    asm volatile("CONDSTORE.32 %0, %2, %1" : "=r"(ret) : "r"(val), "r"(addr) : "memory");
#endif
    return ret;
}
#endif

/* ------------------------------------------------------------------ */
/* CSR numbers — machine mode                                          */
/* ------------------------------------------------------------------ */

#define CSR_MSTATUS     0x300    /* machine status */
#define CSR_MTVEC       0x305    /* trap vector base */
#define CSR_MEPC        0x341    /* exception PC */
#define CSR_MCAUSE      0x342    /* trap cause */
#define CSR_MTVAL       0x343    /* bad address / instruction */
#define CSR_MIE         0x304    /* interrupt enable */
#define CSR_MIP         0x344    /* interrupt pending */
#define CSR_MSCRATCH    0x340    /* scratch register */
#define CSR_MHARTID     0xF14    /* hardware thread ID */
#define CSR_MISA        0x301    /* ISA and extensions */
#define CSR_MEDELEG     0x302    /* machine exception delegation */
#define CSR_MIDELEG     0x303    /* machine interrupt delegation */

#define TVEC_MODE_DIRECT    0
#define TVEC_MODE_VECTORED  1

/* ------------------------------------------------------------------ */
/* CSR numbers — supervisor mode                                        */
/* ------------------------------------------------------------------ */

#define CSR_SSTATUS     0x100    /* supervisor status */
#define CSR_STVEC       0x105    /* supervisor trap vector */
#define CSR_SEPC        0x141    /* supervisor exception PC */
#define CSR_SCAUSE      0x142    /* supervisor trap cause */
#define CSR_STVAL       0x143    /* supervisor bad address */
#define CSR_SIE         0x104    /* supervisor interrupt enable */
#define CSR_SIP         0x144    /* supervisor interrupt pending */
#define CSR_SSCRATCH    0x140    /* supervisor scratch */
#define CSR_SATP        0x180    /* page table base */

/* ------------------------------------------------------------------ */
/* CSR numbers — custom / implementation-defined                       */
/* ------------------------------------------------------------------ */

#define CSR_THREAD_ID   0x7C1    /* hardware thread ID within core */
#define CSR_VIRTUAL_THRD_ID  0x7C3    /* virtual thread ID */
#define CSR_PAGE_MSG_ARG0 0x7C4  /* page message argument 0 */
#define CSR_PAGE_MSG_ARG1 0x7C5  /* page message argument 1 */
#define CSR_PAGE_MSG_CMD  0x7C6  /* page message command */

/* ------------------------------------------------------------------ */
/* MSTATUS bit fields                                                  */
/* ------------------------------------------------------------------ */

#define MSTATUS_MIE     (1UL << 3)    /* machine interrupt enable */
#define MSTATUS_MPIE    (1UL << 7)    /* previous MIE — restored on mret */
#define MSTATUS_MPP_M   (3UL << 11)   /* previous privilege = machine */
#define MSTATUS_MPP_S   (1UL << 11)   /* previous privilege = supervisor */
#define MSTATUS_MPP_U   (0UL << 11)   /* previous privilege = user */

/* ------------------------------------------------------------------ */
/* SSTATUS bit fields                                                  */
/* ------------------------------------------------------------------ */

#define SSTATUS_SIE     (1UL << 1)
#define SSTATUS_SPIE    (1UL << 5)
#define SSTATUS_SPP_S   (1UL << 8)
#define SSTATUS_SPP_U   (0UL << 8)

/* ------------------------------------------------------------------ */
/* MCAUSE / SCAUSE values                                              */
/* ------------------------------------------------------------------ */

#define CAUSE_MISALIGNED_FETCH      0
#define CAUSE_FETCH_ACCESS          1
#define CAUSE_ILLEGAL_INST          2
#define CAUSE_BREAKPOINT            3
#define CAUSE_MISALIGNED_LOAD       4
#define CAUSE_LOAD_ACCESS           5
#define CAUSE_MISALIGNED_STORE      6
#define CAUSE_STORE_ACCESS          7
#define CAUSE_ECALL_U               8   /* syscall from userspace */
#define CAUSE_ECALL_S               9
#define CAUSE_ECALL_M               11
#define CAUSE_FETCH_PAGE_FAULT      12
#define CAUSE_LOAD_PAGE_FAULT       13
#define CAUSE_STORE_PAGE_FAULT      15
#define CAUSE_DOUBLE_TRAP           16
#define CAUSE_SOFTWARE_CHECK        18
#define CAUSE_HARDWARE_ERROR        19
#define CAUSE_FETCH_GUEST_PAGE_FAULT 20
#define CAUSE_LOAD_GUEST_PAGE_FAULT 21
#define CAUSE_VIRTUAL_INSTRUCTION   22
#define CAUSE_STORE_GUEST_PAGE_FAULT 23

#define CAUSE_IRQ_FLAG              ((uintptr_t)1 << (sizeof(uintptr_t) * 8 - 1))  /* set in mcause if interrupt */
#define CAUSE_IRQ_S_SOFTWARE        (CAUSE_IRQ_FLAG | 1)
#define CAUSE_IRQ_VS_SOFTWARE       (CAUSE_IRQ_FLAG | 2)
#define CAUSE_IRQ_M_SOFTWARE        (CAUSE_IRQ_FLAG | 3)
#define CAUSE_IRQ_S_TIMER           (CAUSE_IRQ_FLAG | 5)
#define CAUSE_IRQ_VS_TIMER          (CAUSE_IRQ_FLAG | 6)
#define CAUSE_IRQ_M_TIMER           (CAUSE_IRQ_FLAG | 7)
#define CAUSE_IRQ_S_EXTERNAL        (CAUSE_IRQ_FLAG | 9)
#define CAUSE_IRQ_VS_EXTERNAL       (CAUSE_IRQ_FLAG | 10)
#define CAUSE_IRQ_M_EXTERNAL        (CAUSE_IRQ_FLAG | 11)
#define CAUSE_IRQ_S_GUEST_EXTERNAL  (CAUSE_IRQ_FLAG | 12)
#define CAUSE_IRQ_COUNTER_OVERFLOW  (CAUSE_IRQ_FLAG | 13)

#define CAUSE_TIMER_IRQ             CAUSE_IRQ_M_TIMER
#define CAUSE_EXT_IRQ               CAUSE_IRQ_M_EXTERNAL

/* ------------------------------------------------------------------ */
/* Privileged-instruction helpers                                      */
/* ------------------------------------------------------------------ */

#ifndef __ASSEMBLER__
#define wfi()   asm volatile("wfi")
#define mret()  asm volatile("mret")
#define sret()  asm volatile("sret")
#define fence() asm volatile("fence iorw, rw" ::: "memory")
#endif

#endif /* REGS_H */
