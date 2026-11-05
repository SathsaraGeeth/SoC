#include "fault.h"
#include "../syscall/syscall.h"
#include "../proc/process.h"
#include "../proc/exit/exit.h"
#include "mapping.h"
#include "page.h"
#include "../lib/printk.h"

void handle_page_fault(context_t *ctx, uint32_t cause) {
    addr_t fault_addr = ctx->stval;
    
    if (!current) {
        printk("PANIC: Page fault outside process\r\n");
        while(1);
    }
    
    vma_t *vma = mapping_find_vma(current->mm, fault_addr);
    if (!vma) {
        printk("Segfault: PID %d cause=%u pc=0x%x addr=0x%x\r\n",
               current->pid, cause, ctx->sepc, fault_addr);
        do_exit(-1, ctx);
        return;
    }
    
    if (!mapping_check_perm(vma, cause)) {
        printk("Perm fault: PID %d addr 0x%x\r\n", current->pid, fault_addr);
        do_exit(-1, ctx);
        return;
    }
    
    addr_t vpn = mapping_local_addr(fault_addr) >> PAGE_SHIFT;
    // printk("[FAULTDBG] pid=%d cause=%d addr=%x vpn=%x\r\n",
    //        current_proc->pid, cause, (uint32_t)fault_addr, (uint32_t)vpn);
    page_resolve_fault(current->mm, vma, vpn, cause);
}
