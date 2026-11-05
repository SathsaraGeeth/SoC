/*
 * Comments:
 * 1. TODO: needs the nom!! based impl.
 */

#include "smp.h"
#include <console_early.h>
#include <stdint.h>

static uintptr_t ap_stacks[THREADS_IN_CLUSTER];

/* for now after nom do desired thing */
static void ap_idle(void) {
    uint32_t tid = csr_read(CSR_THREAD_ID);
    uint32_t local_tid = THREAD_OFFSET(tid);
    volatile smp_mailbox_t *mailbox = (volatile smp_mailbox_t *)BL2_SMP_MAILBOX_BASE;
    
    /* clear rel flag to ack smp_init */
    mailbox->ap[local_tid].release_flag = 0;
    fence();
    ipi_trigger_target(0u);
    
    /* wait until kernel release */
    while (mailbox->ap[local_tid].release_flag == 0) {
        wfi();
    }
    
    /* Enter the kernel AP path in S-mode, matching the boot hart.  Calling
     * the entry directly would leave this hart in M-mode, where the kernel's
     * eventual sret to a userspace thread is illegal. */
    void (*entry)(void) = (void (*)(void))mailbox->ap[local_tid].entry_fn;
    uintptr_t medeleg = (1UL << CAUSE_MISALIGNED_FETCH) |
                        (1UL << CAUSE_FETCH_ACCESS) |
                        (1UL << CAUSE_ILLEGAL_INST) |
                        (1UL << CAUSE_BREAKPOINT) |
                        (1UL << CAUSE_MISALIGNED_LOAD) |
                        (1UL << CAUSE_LOAD_ACCESS) |
                        (1UL << CAUSE_MISALIGNED_STORE) |
                        (1UL << CAUSE_STORE_ACCESS) |
                        (1UL << CAUSE_ECALL_U) |
                        (1UL << CAUSE_FETCH_PAGE_FAULT) |
                        (1UL << CAUSE_LOAD_PAGE_FAULT) |
                        (1UL << CAUSE_STORE_PAGE_FAULT);
    csr_write(CSR_MEDELEG, medeleg);
    csr_write(CSR_MIDELEG, 1UL << 7);
    csr_write(CSR_MEPC, (uintptr_t)entry);
    csr_write(CSR_MSTATUS, MSTATUS_MPP_S | MSTATUS_MPIE);
    mret();
    __builtin_unreachable();
}

/* currently all fns are idle and same */
void smp_init(void) {
    volatile smp_mailbox_t *mailbox = (volatile smp_mailbox_t *)BL2_SMP_MAILBOX_BASE;
    uint8_t *all_stacks = (uint8_t *)kmalloc(BL2_SMP_STACK_SIZE * (THREADS_IN_CLUSTER - 1));

    for (uint32_t i = 1; i < THREADS_IN_CLUSTER; i++) {
        uintptr_t sp = (uintptr_t)(all_stacks + BL2_SMP_STACK_SIZE * i);
        ap_stacks[i] = sp;
        mailbox->ap[i].stack_ptr = sp;
        mailbox->ap[i].entry_fn = (uintptr_t)ap_idle;
        mailbox->ap[i].release_flag = 1;
    }
    fence();
    ipi_trigger_secondary(0u);
    
    for (uint32_t i = 1; i < THREADS_IN_CLUSTER; i++) {
        while (mailbox->ap[i].release_flag != 0) {
            wfi();
        }
    }
    console_early_puts("[SMP] APs released\r\n");
}
