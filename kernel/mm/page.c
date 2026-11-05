#include "page.h"
#include "frame.h"
#include "clock.h"
#include "page_msg.h"
#include "mapping.h"
#include "../fs/file.h"
#include "../proc/process.h"
#include "../lib/printk.h"
#include <stddef.h>

static page_t pages[4096];
static int next_page_idx = 0;

void page_system_init(void) {
    for (int i = 0; i < 4096; i++) {
        pages[i].refcount = 0;
        pages[i].present = 0;
    }
}

page_t *page_lookup(addr_t backing_pa) {
    for (int i = 0; i < next_page_idx; i++) {
        if (pages[i].present && pages[i].backing_pa == backing_pa) {
            return &pages[i];
        }
    }
    return NULL;
}

page_t *page_create(addr_t backing_pa) {
    for (int i = 0; i < next_page_idx; i++) {
        if (!pages[i].present) {
            pages[i].backing_pa = backing_pa;
            pages[i].sram_ppn = -1;
            pages[i].refcount = 1;
            pages[i].dirty = 0;
            pages[i].present = 1;
            return &pages[i];
        }
    }
    if (next_page_idx >= 4096) return NULL;
    page_t *p = &pages[next_page_idx++];
    p->backing_pa = backing_pa;
    p->sram_ppn = -1;
    p->refcount = 1;
    p->dirty = 0;
    p->present = 1;
    return p;
}

void page_ref(page_t *p) {
    if (p && p->present) {
        p->refcount++;
    }
}

void page_unref(page_t *p) {
    if (p && p->present) {
        if (p->refcount > 0) {
            p->refcount--;
        }
        if (p->refcount == 0) {
            if (p->sram_ppn != -1) {
                frame_free(p->sram_ppn);
                p->sram_ppn = -1;
            }
            if (p->backing_pa != 0) {
                backing_free(p->backing_pa);
                p->backing_pa = 0;
            }
            p->present = 0;
        }
    }
}

static int evict_one_frame(void) {
    addr_t out_backing_pa;
    int victim_ppn = clock_evict(&out_backing_pa);
    if (victim_ppn == -1) return -1;

    page_t *victim_p = page_lookup(out_backing_pa);
    if (victim_p) {
        if (clock_is_dirty(victim_ppn)) {
            page_msg_store(victim_p->backing_pa >> PAGE_SHIFT, victim_ppn);
        }
        victim_p->sram_ppn = -1;
    }
    /* Bug6 fix: return the frame to the free pool so frame_alloc can hand it out
       properly and the bitmap stays in sync with the clock state. */
    frame_free(victim_ppn);
    return victim_ppn;
}

void page_resolve_fault(mm_t *mm, vma_t *vma, addr_t vpn, uint32_t cause) {
    int is_user = 1;
    int is_store = (cause == 15);
    
    pte_t *pte = mapping_get_pte(mm, vpn, 1);
    if (!pte) { printk("OOM PTE\r\n"); return; }
    
    page_t *p = NULL;
    if (*pte & PTE_V) {
        addr_t backing_pa = *pte & ~(PAGE_SIZE - 1);
        p = page_lookup(backing_pa);
    }
    
    // Check for COW
    if (p && is_store && !(*pte & PTE_W)) {
        if (p->refcount > 1) {
            addr_t new_backing_pa = backing_alloc();
            page_t *new_p = page_create(new_backing_pa);
            if (!new_p) { printk("OOM COW page\r\n"); return; }
            
            new_p->sram_ppn = frame_alloc();
            if (new_p->sram_ppn == -1) {
                evict_one_frame(); /* frees a frame back into the pool */
                new_p->sram_ppn = frame_alloc();
            }
            if (new_p->sram_ppn == -1) { printk("OOM eviction COW\r\n"); return; }
            
            if (p->sram_ppn == -1) {
                p->sram_ppn = frame_alloc();
                if (p->sram_ppn == -1) {
                    evict_one_frame();
                    p->sram_ppn = frame_alloc();
                }
                if (p->sram_ppn == -1) { printk("OOM eviction src COW\r\n"); return; }
                page_msg_load(p->backing_pa >> PAGE_SHIFT, p->sram_ppn);
                clock_record_access(p->sram_ppn, p->backing_pa);
            }
            
            uintptr_t *src = (uintptr_t *)((uintptr_t)p->sram_ppn << PAGE_SHIFT);
            uintptr_t *dst = (uintptr_t *)((uintptr_t)new_p->sram_ppn << PAGE_SHIFT);
            for (int i = 0; i < PAGE_SIZE / sizeof(*dst); i++) dst[i] = src[i];
            
            page_unref(p);
            p = new_p;
            /* The new frame is dirty.  Its backing page is populated lazily
             * by normal clock eviction, avoiding a synchronous transfer on
             * every first write after fork. */
            clock_record_access(p->sram_ppn, p->backing_pa);
            
            mapping_map_page(mm, vpn, p->backing_pa, vma->prot, is_user);
        }
        *pte |= PTE_W;
        if (p->sram_ppn != -1) {
            clock_mark_dirty(p->sram_ppn);
            addr_t data0 = (vpn << PAGE_SHIFT) | ((addr_t)is_user << (PAGE_SHIFT - 1)) |
                           ((addr_t)((*pte & PTE_W) != 0) << (PAGE_SHIFT - 2)) | mm->asid;
            page_msg_tlb_update(data0, p->sram_ppn);
        }
        return;
    }
    
    if (!p) {
        addr_t new_backing_pa = backing_alloc();
        if (!new_backing_pa) { printk("OOM backing\r\n"); return; }
        
        p = page_create(new_backing_pa);
        if (!p) { printk("OOM page_t\r\n"); return; }
        
        p->sram_ppn = frame_alloc();
        if (p->sram_ppn == -1) {
            evict_one_frame(); /* frees a frame, then alloc it properly */
            p->sram_ppn = frame_alloc();
            if (p->sram_ppn == -1) { printk("OOM eviction\r\n"); return; }
        }
        
        page_msg_load(p->backing_pa >> PAGE_SHIFT, p->sram_ppn);
        // printk("[PAGEDBG] load returned vpn=%x ppn=%d backing=%x_%x\r\n",
        //        (uint32_t)vpn, p->sram_ppn,
        //        (uint32_t)(p->backing_pa >> 32), (uint32_t)p->backing_pa);
        clock_record_access(p->sram_ppn, p->backing_pa);
        
        uintptr_t *s_page = (uintptr_t *)((uintptr_t)p->sram_ppn << PAGE_SHIFT);

        /* A fresh executable page must not inherit backing-store contents in
         * the ELF segment's BSS tail.  Zero first, then copy only p_filesz. */
        for (int i = 0; i < PAGE_SIZE / sizeof(*s_page); i++) s_page[i] = 0;
        // printk("[PAGEDBG] zero complete vpn=%x\r\n", (uint32_t)vpn);
        
        if (!(vma->flags & MAP_ANONYMOUS) && vma->fd >= 0) {
            file_t *f = current ? fd_get(current->files, vma->fd) : 0;
            if (f && f->vnode) {
                addr_t page_off = (vpn << PAGE_SHIFT) - vma->vaddr_start;
                if (page_off < vma->file_size) {
                    size_t valid = vma->file_size - page_off;
                    if (valid > PAGE_SIZE) valid = PAGE_SIZE;
                    uint32_t pos = (uint32_t)(vma->offset + page_off);
                    f->vnode->ops->read(f->vnode, (void*)s_page, valid, &pos);
                    // printk("[PAGEDBG] file read complete vpn=%x bytes=%d pos=%x\r\n",
                    //        (uint32_t)vpn, (uint32_t)valid, pos);
                }
            }
        }
        // printk("[PAGE] Loaded page vpn=%x val=0x%x\r\n", vpn, s_page[0]);
        
        if (is_store) clock_mark_dirty(p->sram_ppn);
        
        mapping_map_page(mm, vpn, p->backing_pa, vma->prot, is_user);
        // printk("[PAGEDBG] mapped vpn=%x asid=%d\r\n", (uint32_t)vpn, mm->asid);
        
        addr_t data0 = (vpn << PAGE_SHIFT) | ((addr_t)is_user << (PAGE_SHIFT - 1)) |
                       ((addr_t)((*pte & PTE_W) != 0) << (PAGE_SHIFT - 2)) | mm->asid;
        page_msg_tlb_update(data0, p->sram_ppn);
        // printk("[PAGEDBG] tlb update posted vpn=%x data=%x_%x\r\n",
        //        (uint32_t)vpn, (uint32_t)(data0 >> 32), (uint32_t)data0);
        
    } else {
        if (p->sram_ppn == -1) {
            p->sram_ppn = frame_alloc();
            if (p->sram_ppn == -1) {
                evict_one_frame();
                p->sram_ppn = frame_alloc();
                if (p->sram_ppn == -1) { printk("OOM eviction\r\n"); return; }
            }
            page_msg_load(p->backing_pa >> PAGE_SHIFT, p->sram_ppn);
        }
        clock_record_access(p->sram_ppn, p->backing_pa);
        if (is_store) clock_mark_dirty(p->sram_ppn);
        
        addr_t data0 = (vpn << PAGE_SHIFT) | ((addr_t)is_user << (PAGE_SHIFT - 1)) |
                       ((addr_t)((*pte & PTE_W) != 0) << (PAGE_SHIFT - 2)) | mm->asid;
        page_msg_tlb_update(data0, p->sram_ppn);
    }
}
