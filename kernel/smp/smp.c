#include "smp.h"
#include "../lib/printk.h"
#include "../mm/frame.h"
#include "../proc/process.h"
#include "../proc/sched/sched.h"
#include "../trap/trap.h"
#include <soc.h>
#include <regs.h>

thread_t threads[THREADS_IN_CLUSTER];
volatile uint32_t num_threads_online = 1;
static volatile uint32_t thread_online_flags[THREADS_IN_CLUSTER];
static struct task_struct secondary_idle[THREADS_IN_CLUSTER];

uintptr_t _thread_stack_table[THREADS_IN_CLUSTER];

extern void smp_secondary_entry(void);

static void secondary_idle_loop(void)
{
    uint32_t tid = smp_get_tid();
    for (;;) {
        struct task_struct *next = sched_take_next();
        if (next) {
            if (next->context.sstatus & SSTATUS_SPP_S) {
                /* Spawned processes first run their kernel exec trampoline. */
                switch_to(&secondary_idle[tid], next);
            } else {
                process_finish_switch(next);
                process_enter_user(&next->context,
                    (uintptr_t)next->stack + PROC_STACK_SIZE);
            }
        }
        threads[tid].state = THREAD_IDLE;
        wfi();
    }
}

void smp_init(void) {
    uint32_t boot_tid = smp_get_tid();
    
    printk("[SMP] initialized\r\n");
    
    threads[boot_tid].tid       = boot_tid;
    threads[boot_tid].state     = THREAD_ONLINE;
    threads[boot_tid].stack_top = 0;
    thread_online_flags[boot_tid] = 1;
    
    /* stack setup for all threads */
    for (uint32_t i = 0; i < THREADS_IN_CLUSTER; i++) {
        _thread_stack_table[i] = 0;
    }
    for (uint32_t i = 0; i < THREADS_IN_CLUSTER; i++) {
        if (i == boot_tid) continue;
        int stack_ppn = frame_alloc();
        if (stack_ppn < 0) {
            printk("[SMP] stack frame allocation failed for cpu %u\r\n", i);
            return;
        }
        uintptr_t sp = ((uintptr_t)stack_ppn + 1u) * PAGE_SIZE;
        
        _thread_stack_table[i] = sp;
        threads[i].tid               = i;
        threads[i].state             = THREAD_BOOTING;
        threads[i].stack_top         = sp;
        SMP_MAILBOX->ap[i].stack_ptr = sp;
        SMP_MAILBOX->ap[i].entry_fn  = (uint32_t)smp_secondary_entry;
        SMP_MAILBOX->ap[i].release_flag = 1;
    }
    fence();
    ipi_trigger_secondary(boot_tid); /* wake other threads */

    for (uint32_t wait = 0; wait < 10000u; wait++) {
        uint32_t online = 0;
        for (uint32_t i = 0; i < THREADS_IN_CLUSTER; i++) {
            online += thread_online_flags[i] != 0;
        }
        num_threads_online = online;
        if (online >= THREADS_IN_CLUSTER) {
            break;
        }
        __asm__ volatile ("nop");
    }

    printk("[SMP] online count %d/%d\r\n", num_threads_online, THREADS_IN_CLUSTER);
}

void smp_secondary_main(void) {
    uint32_t tid = smp_get_tid();
    struct task_struct *idle = &secondary_idle[tid];

    /* stvec and sscratch are per-hardware-thread CSRs. */
    trap_init();
    idle->pid = 0;
    idle->state = TASK_RUNNING;
    idle->context.r2 = _thread_stack_table[tid];
    idle->context.sepc = (uintptr_t)secondary_idle_loop;
    idle->context.sstatus = SSTATUS_SPP_S | SSTATUS_SPIE;
    sched_set_idle(idle);
    sched_set_current(idle);
    
    threads[tid].tid       = tid;
    threads[tid].state     = THREAD_ONLINE;
    thread_online_flags[tid] = 1;
    fence();

    secondary_idle_loop();
}
