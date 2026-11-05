#include "mapping.h"
#include "page.h"
#include "slab.h"
#include "page_msg.h"

int mapping_check_perm(vma_t *vma, uint32_t cause) {
    if (cause == 15 && !(vma->prot & PROT_WRITE)) return 0;
    if (cause == 12 && !(vma->prot & PROT_EXEC)) return 0;
    return 1;
}

vma_t *mapping_find_vma(mm_t *mm, addr_t addr) {
    if (!mm) return NULL;
    addr = mapping_local_addr(addr);
    for (int i = 0; i < MAX_VMAS; i++) {
        if (mm->vmas[i].used &&
            addr >= mm->vmas[i].vaddr_start &&
            addr < mm->vmas[i].vaddr_end) {
            return &mm->vmas[i];
        }
    }
    return NULL;
}

pte_t *mapping_get_pte(mm_t *mm, addr_t vpn, int alloc) {
    /* Mesh coordinates are routing metadata, not part of a process's local
       virtual-page number. The hardware TLB is populated through page
       messages, so the kernel only needs a sparse full-width software map. */
    vpn &= REGION_OFFSET_MASK >> PAGE_SHIFT;

    if (!mm->page_map) {
        if (!alloc) return NULL;
        mm->page_map = (pte_slot_t *)kmalloc(sizeof(pte_slot_t) * MAX_SW_PTES);
        if (!mm->page_map) return NULL;
        for (int i = 0; i < MAX_SW_PTES; i++) {
            mm->page_map[i].vpn_plus_one = 0;
            mm->page_map[i].pte = 0;
        }
    }

    addr_t key = vpn + 1;
    pte_slot_t *free_slot = NULL;
    for (int i = 0; i < MAX_SW_PTES; i++) {
        if (mm->page_map[i].vpn_plus_one == key) {
            return &mm->page_map[i].pte;
        }
        if (!free_slot && mm->page_map[i].vpn_plus_one == 0) {
            free_slot = &mm->page_map[i];
        }
    }

    if (!alloc || !free_slot) return NULL;
    free_slot->vpn_plus_one = key;
    free_slot->pte = 0;
    return &free_slot->pte;
}

void mapping_map_page(mm_t *mm, addr_t vpn, addr_t pa, uint32_t prot, int is_user) {
    pte_t *pte = mapping_get_pte(mm, vpn, 1);
    if (!pte) return;
    
    *pte = pa | PTE_V | PTE_R | PTE_X | (is_user ? PTE_U : 0);
    if (prot & PROT_WRITE) *pte |= PTE_W;
}

void mapping_activate(mm_t *mm) {
    if (!mm || !mm->page_map) return;
    for (int i = 0; i < MAX_SW_PTES; i++) {
        pte_slot_t *slot = &mm->page_map[i];
        if (!slot->vpn_plus_one || !(slot->pte & PTE_V)) continue;
        page_t *page = page_lookup(slot->pte & ~(PAGE_SIZE - 1));
        if (!page || page->sram_ppn < 0) continue;
        addr_t vpn = slot->vpn_plus_one - 1;
        addr_t data0 = (vpn << PAGE_SHIFT) |
                       ((addr_t)((slot->pte & PTE_U) != 0) << (PAGE_SHIFT - 1)) |
                       ((addr_t)((slot->pte & PTE_W) != 0) << (PAGE_SHIFT - 2)) |
                       mm->asid;
        page_msg_tlb_update(data0, page->sram_ppn);
    }
}

void mapping_fork_vma(mm_t *parent_mm, mm_t *child_mm, vma_t *vma) {
    int vma_index = (int)(vma - parent_mm->vmas);
    if (vma_index < 0 || vma_index >= MAX_VMAS) return;
    child_mm->vmas[vma_index] = *vma;

    addr_t start_vpn = vma->vaddr_start >> PAGE_SHIFT;
    addr_t end_vpn = (vma->vaddr_end + PAGE_SIZE - 1) >> PAGE_SHIFT;

    for (addr_t vpn = start_vpn; vpn < end_vpn; vpn++) {
        pte_t *p_pte = mapping_get_pte(parent_mm, vpn, 0);
        if (!p_pte || !(*p_pte & PTE_V)) continue;

        pte_t *c_pte = mapping_get_pte(child_mm, vpn, 1);
        if (!c_pte) return;
        addr_t backing_pa = *p_pte & ~(PAGE_SIZE - 1);
        page_t *page = page_lookup(backing_pa);
        if (page) page_ref(page);
        *p_pte &= ~PTE_W;
        *c_pte = *p_pte;
        if (page && page->sram_ppn >= 0) {
            addr_t parent_data = (vpn << PAGE_SHIFT) |
                                 ((addr_t)((*p_pte & PTE_U) != 0) << (PAGE_SHIFT - 1)) |
                                 parent_mm->asid;
            page_msg_tlb_update(parent_data, page->sram_ppn);
        }
    }
}

void mapping_free_vma(mm_t *mm, vma_t *vma) {
    addr_t start_vpn = vma->vaddr_start >> PAGE_SHIFT;
    addr_t end_vpn = (vma->vaddr_end + PAGE_SIZE - 1) >> PAGE_SHIFT;

    if (!mm || !mm->page_map)
        return;

    /* page_map is sparse.  Walking every VPN and searching the whole table
       for each one turns exec teardown into O(VPNs * PTE slots). */
    for (int i = 0; i < MAX_SW_PTES; ++i) {
        pte_slot_t *slot = &mm->page_map[i];
        addr_t vpn;
        addr_t backing_pa;
        page_t *p;

        if (!slot->vpn_plus_one)
            continue;
        vpn = slot->vpn_plus_one - 1;
        if (vpn < start_vpn || vpn >= end_vpn)
            continue;
        if (!(slot->pte & PTE_V)) {
            slot->vpn_plus_one = 0;
            continue;
        }

        backing_pa = slot->pte & ~(PAGE_SIZE - 1);
        p = page_lookup(backing_pa);
        if (p)
            page_unref(p);
        slot->pte = 0;
        slot->vpn_plus_one = 0;
    }
}
