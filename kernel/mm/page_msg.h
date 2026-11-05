#ifndef PAGE_MSG_H
#define PAGE_MSG_H

#include <stdint.h>

#define PAGE_MSG_PAGE_LOAD   3
#define PAGE_MSG_PAGE_STORE  4
#define PAGE_MSG_PAGE_EVICT  4
#define PAGE_MSG_TLB_UPDATE  2

void page_msg_load(uintptr_t backing_pa, uintptr_t sram_ppn);
void page_msg_store(uintptr_t backing_pa, uintptr_t sram_ppn);
void page_msg_tlb_update(uintptr_t data0, uintptr_t sram_ppn);

#endif
