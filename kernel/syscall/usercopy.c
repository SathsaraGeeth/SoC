#include "usercopy.h"
#include <proc/process.h>
#include <mm/memory.h>
#include <mm/page.h>

static int user_window(addr_t address, uint8_t **kernel, size_t *available, uint32_t cause) {
    addr_t local;
    addr_t vpn;
    vma_t *vma;
    pte_t *pte;
    page_t *page;

    if (!current || !kernel || !available)
        return -1;
    vma = mapping_find_vma(current->mm, address);
    if (!vma || !mapping_check_perm(vma, cause))
        return -1;
    local = mapping_local_addr(address);
    vpn = local >> PAGE_SHIFT;
    pte = mapping_get_pte(current->mm, vpn, 0);
    if (!pte || !(*pte & PTE_V) || (cause == 15 && !(*pte & PTE_W))) {
        page_resolve_fault(current->mm, vma, vpn, cause);
        pte = mapping_get_pte(current->mm, vpn, 0);
    }
    if (!pte || !(*pte & PTE_V))
        return -1;
    page = page_lookup(*pte & ~(addr_t)(PAGE_SIZE - 1));
    if (!page)
        return -1;
    if (page->sram_ppn == -1)
        page_resolve_fault(current->mm, vma, vpn, cause);
    if (page->sram_ppn == -1)
        return -1;
    *kernel = (uint8_t *)((uintptr_t)page->sram_ppn << PAGE_SHIFT);
    *kernel += local & (PAGE_SIZE - 1);
    *available = PAGE_SIZE - (local & (PAGE_SIZE - 1));
    return 0;
}

int copy_from_user(void *destination, const void *source, size_t size) {
    uint8_t *out = destination;
    addr_t address = (addr_t)source;
    while (size) {
        uint8_t *in;
        size_t available;
        size_t chunk;
        if (user_window(address, &in, &available, 13) < 0)
            return -1;
        chunk = size < available ? size : available;
        mm_memcpy(out, in, chunk);
        out += chunk;
        address += chunk;
        size -= chunk;
    }
    return 0;
}

int copy_to_user(void *destination, const void *source, size_t size) {
    addr_t address = (addr_t)destination;
    const uint8_t *in = source;
    while (size) {
        uint8_t *out;
        size_t available;
        size_t chunk;
        if (user_window(address, &out, &available, 15) < 0)
            return -1;
        chunk = size < available ? size : available;
        mm_memcpy(out, in, chunk);
        out += chunk;
        in += chunk;
        address += chunk;
        size -= chunk;
    }
    return 0;
}

int copy_string_from_user(char *destination, const char *source, size_t capacity) {
    size_t copied = 0;
    if (!destination || !source || !capacity)
        return -1;
    while (copied + 1 < capacity) {
        uint8_t *in;
        size_t available;
        size_t chunk = capacity - copied - 1;
        size_t index;
        if (user_window((addr_t)source + copied, &in, &available, 13) < 0)
            return -1;
        if (chunk > available)
            chunk = available;
        for (index = 0; index < chunk; ++index) {
            destination[copied++] = (char)in[index];
            if (!in[index])
                return 0;
        }
    }
    destination[capacity - 1] = '\0';
    return -1;
}
