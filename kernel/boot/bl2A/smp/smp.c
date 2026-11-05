/* 
 * kernel/boot/bl2/smp/smp.c
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

/*
 * Comments:
 * 1. TODO: needs the nom!! based impl.
 */

#include "smp.h"
#include <console_early.h>
#include <stdint.h>

static uint32_t ap_stacks[THREADS_IN_CLUSTER];

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
    /* call kernel's entry */
    void (*entry)(void) = (void (*)(void))mailbox->ap[local_tid].entry_fn;
    entry();
}

/* currently all fns are idle and same */
void smp_init(void) {
    volatile smp_mailbox_t *mailbox = (volatile smp_mailbox_t *)BL2_SMP_MAILBOX_BASE;
    uint8_t *all_stacks = (uint8_t *)kmalloc(BL2_SMP_STACK_SIZE * (THREADS_IN_CLUSTER - 1));

    for (uint32_t i = 1; i < THREADS_IN_CLUSTER; i++) {
        uint32_t sp = (uint32_t)(all_stacks + BL2_SMP_STACK_SIZE * i);
        ap_stacks[i] = sp;
        mailbox->ap[i].stack_ptr = sp;
        mailbox->ap[i].entry_fn = (uint32_t)ap_idle;
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
