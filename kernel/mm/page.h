#ifndef MM_PAGE_H
#define MM_PAGE_H

#include <stdint.h>
#include "mapping.h"

typedef struct page {
    addr_t backing_pa;
    int sram_ppn;   // -1 if not loaded
    uint8_t refcount;
    uint8_t dirty;
    uint8_t present;
} page_t;

void page_system_init(void);
page_t *page_lookup(addr_t backing_pa);
page_t *page_create(addr_t backing_pa);
void page_ref(page_t *p);
void page_unref(page_t *p);

void page_resolve_fault(mm_t *mm, vma_t *vma, addr_t vpn, uint32_t cause);

#endif
