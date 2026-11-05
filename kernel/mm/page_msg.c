#include "page_msg.h"
#include <regs.h>

void page_msg_load(uintptr_t backing_pa, uintptr_t sram_ppn) {
    csr_write(CSR_PAGE_MSG_ARG0, backing_pa);
    csr_write(CSR_PAGE_MSG_ARG1, sram_ppn);
    csr_write(CSR_PAGE_MSG_CMD, PAGE_MSG_PAGE_LOAD);
    wfi();
}

void page_msg_store(uintptr_t backing_pa, uintptr_t sram_ppn) {
    csr_write(CSR_PAGE_MSG_ARG0, backing_pa);
    csr_write(CSR_PAGE_MSG_ARG1, sram_ppn);
    csr_write(CSR_PAGE_MSG_CMD, PAGE_MSG_PAGE_STORE);
    wfi();
}

void page_msg_tlb_update(uintptr_t data0, uintptr_t sram_ppn) {
    csr_write(CSR_PAGE_MSG_ARG0, data0);
    csr_write(CSR_PAGE_MSG_ARG1, sram_ppn);
    csr_write(CSR_PAGE_MSG_CMD, PAGE_MSG_TLB_UPDATE);
}
