#include <stdint.h>
#include <console_early.h>
#include <load.h>
#include <soc.h>
#include <regs.h>
#include <nom.h>
#include "nom/nom.h"

#define ALIVE_MSG 0xDEADBEEF
static uint32_t timer_us(void) {
    volatile uint32_t *mtime = (volatile uint32_t *)TIMER_MMIO_BASE;
    uint32_t hi, lo, hi_check;
    uint64_t ticks;

    do {
        hi = mtime[1];
        lo = mtime[0];
        hi_check = mtime[1];
    } while (hi != hi_check);
    ticks = ((uint64_t)hi << 32) | lo;
    return (uint32_t)(ticks / (CLOCK_FREQ_HZ / 1000000ULL));
}

static void print_elapsed(const char *label, uint32_t start) {
    console_early_puts(label);
    console_early_putdec32(timer_us() - start);
    console_early_puts(" us\r\n");
}


extern uintptr_t ap_entry_fn;
extern uint32_t ap_release_flag;

typedef void (*entry_fn)(void);

static inline void jump_to(uintptr_t addr) {
    __asm__ volatile ("fence.i" ::: "memory");
    entry_fn fn = (entry_fn)addr;
    fn();
}

void load_bl2(void) {
    uint64_t ntxns = BL2_SIZE / BLOCK_SIZE;
    for (uint64_t i = 0; i < ntxns; i++) {
        uint64_t src_block = (BL2_BASE_BA + i * BLOCK_SIZE) / BLOCK_SIZE;
        uint64_t dest_ppn  = (BL2_BASE    + i * PAGE_SIZE ) / PAGE_SIZE;
        load_block((uint32_t)src_block, (uint32_t)dest_ppn);
        console_early_puts(".");
    }
    console_early_puts("\r\n");
}

void load_bl2a(void) {
    uint64_t ntxns = BL2A_SIZE / BLOCK_SIZE;
    for (uint64_t i = 0; i < ntxns; i++) {
        uint64_t src_block = (BL2A_BASE_BA + i * BLOCK_SIZE) / BLOCK_SIZE;
        uint64_t dest_ppn  = (KERNEL_BASE  + i * PAGE_SIZE ) / PAGE_SIZE;
        load_block((uint32_t)src_block, (uint32_t)dest_ppn);
        console_early_puts(".");
    }
    console_early_puts("\r\n");
}

volatile uint32_t bl2_loaded_flag = 0;

void bl1_main(void) {
    uint32_t tid       = csr_read(CSR_THREAD_ID);
    uint32_t local_tid = THREAD_OFFSET(tid);
    uint32_t region_id = get_my_region_id(tid);
    uint32_t boot_start = 0;

    // if (local_tid == 0) {
    //     (void)nom_early_init();
    // }

    /* The global hardware thread-zero is the unique BL1 boot master. */
    if (tid == 0) {
        console_early_init();
        boot_start = timer_us();
        uint32_t stage_start;
        // console_early_puts("[BL1] initializing a nom mailbox\r\n");
        console_early_puts("[BL1] parked all other threads in the cluster\r\n");

        console_early_puts("[BL1] loading BL2\r\n");
        stage_start = timer_us();
        load_bl2();
        print_elapsed("[TIME] BL1 load BL2: ", stage_start);
        console_early_puts("[BL1] loading BL2A\r\n");
        // stage_start = timer_us();
        // load_bl2a();
        // print_elapsed("[TIME] BL1 load BL2A: ", stage_start);

        ap_entry_fn = BL2_BASE;
        ap_release_flag = 1;
        fence();
        bl2_loaded_flag = 1;
        console_early_puts("[BL1] waking all threads again\r\n");
        ipi_trigger_secondary(0u);

    } else if (region_id == 0) {
        while (bl2_loaded_flag == 0) {
            wfi();  // others sleep until the bl2 is loaded
        }
        // nom_transfer_worker_loop(tid);
        return;
    }

    // if (local_tid == 0 && region_id != 0) {
    //     nom_early_message_t msg = {
    //         .message_id = 0x0,
    //         .sender_tid = tid,
    //         .receiver_tid = 0,
    //         .is_broadcast = false,
    //         .original_sender_tid = tid,
    //         .final_receiver_tid = 0,
    //         .valid = NOM_EARLY_MESSAGE_VALID,
    //         .payload = ALIVE_MSG
    //     };
    //     nom_early_message(&msg);
    //     bl1_nom_secondary_listen_loop(tid, region_id);
    // }

    // if (local_tid == 0 && region_id == 0) {
        // console_early_puts("[BL1] early nom check\r\n");
        // uint32_t nom_start = timer_us();
        // uint32_t count = 0;
        // uint32_t seen[NUM_REGIONS];

        // for (uint32_t i = 0; i < NUM_REGIONS; i++) {
        //     seen[i] = 0;
        // }

        // while (count < (NUM_REGIONS - 1)) {
        //     nom_early_message_t msg = nom_early_read_message();
        //     uint32_t sender_region = get_my_region_id(msg.original_sender_tid);

        //     if (msg.valid && msg.payload == ALIVE_MSG) {
        //         if (sender_region == 0u || sender_region >= NUM_REGIONS || seen[sender_region] != 0u) {
        //             continue;
        //         }

        //         seen[sender_region] = 1;
        //         console_early_puts("[BL1] received alive message from region ");
        //         console_early_puthex32(sender_region);
        //         console_early_puts("\r\n");
        //         count++;
        //     }
        // }
        // print_elapsed("[TIME] BL1 NOM alive messages: ", nom_start);

        // console_early_puts("[BL1] directed transfer of BL2 to region 7\r\n");
        // nom_start = timer_us();
        // bl1_nom_transfer_bl2_to_region(tid, 7);
        // console_early_puts("[BL1] directed transfer complete\r\n");
        // print_elapsed("[TIME] BL1 NOM directed transfer: ", nom_start);

        // console_early_puts("[BL1] Requesting sparse checksum for directed transfer...\r\n");
        // nom_start = timer_us();
        // bool match1 = bl1_nom_request_and_verify_checksum(tid, 7);
        // if (match1) {
        //     console_early_puts("[BL1] Checksum MATCH!\r\n");
        // } else {
        //     console_early_puts("[BL1] Checksum MISMATCH!\r\n");
        // }
        // print_elapsed("[TIME] BL1 NOM directed checksum: ", nom_start);

    //     // console_early_puts("[BL1] broadcasting BL2 to all regions\r\n");
    //     // nom_start = timer_us();
    //     // bl1_nom_transfer_bl2_broadcast(tid);
    //     // console_early_puts("[BL1] BL2 broadcast complete\r\n");
    //     // print_elapsed("[TIME] BL1 NOM broadcast: ", nom_start);

    //     // console_early_puts("[BL1] Requesting sparse checksum\r\n");
    //     // nom_start = timer_us();
    //     // bool match = bl1_nom_request_and_verify_checksum(tid, 1);
    //     // if (match) {
    //     //     console_early_puts("[BL1] Checksum MATCH!\r\n");
    //     // } else {
    //     //     console_early_puts("[BL1] Checksum MISMATCH!\r\n");
    //     // }
    //     // print_elapsed("[TIME] BL1 NOM broadcast checksum: ", nom_start);
    //     // nom_transfer_stop_workers();
    //     print_elapsed("[TIME] BL1 total: ", boot_start);
    // }


    if (tid == 0) {
        console_early_puts("[BL1] jump to BL2\r\n");
        jump_to(BL2_BASE);
    }

    while (1) {
        wfi();
    }
}
