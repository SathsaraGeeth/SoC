#include <stdint.h>
#include "../mm/slab.h"
#include "../fs/vfs.h"
#include "../proc/process.h"
#include "../proc/exec/exec.h"
#include "../drivers/core/dev.h"
#include "../drivers/uart/uart_dev.h"
#include "../drivers/video/framebuffer_dev.h"
#include "../drivers/sysarr/sys_array_dev.h"
#include "../proc/ipc/pipe.h"
#include "../proc/ipc/shm.h"
#include "../trap/trap.h"
#include "../syscall/syscall.h"
#include "../drivers/timer/timer.h"
#include "../lib/printk.h"
#include "../mm/frame.h"
#include "../mm/page.h"
#include "../mm/clock.h"
#include "../smp/smp.h"
#include "../sync/futex.h"
#include "../sync/rcu.h"
#include <soc.h>
#include <regs.h>

extern char _kernel_bss_end;
#define KERNEL_HEAP_START ((uintptr_t)&_kernel_bss_end)

extern void uart_puts(const char *s);
extern void uart_putc(char c);
extern void uart_init(void);
extern void console_early_putc(char c);
extern void context_switch(context_t *from, context_t *to);

static uint32_t elapsed_us(uint64_t start) {
    uint64_t ticks = timer_get_time() - start;
    return (uint32_t)(ticks / (CLOCK_FREQ_HZ / 1000000ULL));
}

static void print_elapsed(const char *label, uint64_t start) {
    printk("[TIME] %s%u us\r\n", label, elapsed_us(start));
}

/* The kernel and its first task run in S-mode.  Applications are entered
 * with sret and thereafter run in U-mode. */
static void init_task(void) {
    static const char init_path[] = "/bin/init.elf";
    printk("[INIT] loading userspace %s\r\n", init_path);

    /*
     * current->context is the destination user context while do_exec() is
     * prefaulting the image.  A timer interrupt here would save the
     * interrupted S-mode frame over it, so keep the bootstrap transition
     * non-preemptible through the final sret.  SSTATUS_SPIE in the new frame
     * enables interrupts again after entering U-mode.
     */
    trap_disable();
    if (do_exec(&current->context, init_path) < 0) {
        printk("[INIT] cannot load %s\r\n", init_path);
        while (1) { __asm__ volatile ("wfi"); }
    }
    /* The bootstrap path bypasses proc_schedule(), which normally selects
     * this ASID before returning to a user context. */
    csr_write(CSR_VIRTUAL_THRD_ID, current->mm->asid & 0xFF);
    printk("[INIT] entering U-mode\r\n");
    process_enter_user(&current->context,
                       (uintptr_t)current->stack + PROC_STACK_SIZE);
}

void kernel_main(void) {
    uart_init();
    printk_init(console_early_putc);
    uint64_t boot_start = timer_get_time();
    uint64_t stage_start;

    printk("[KERNEL] DMCTP kernel initialized\r\n");
    
    stage_start = timer_get_time();
    slab_init(KERNEL_HEAP_START, KERNEL_HEAP_SIZE);
    printk("[INIT] slab allocator initialized\r\n");
    print_elapsed("kernel slab: ", stage_start);

    stage_start = timer_get_time();
    frame_alloc_init();
    page_system_init();
    clock_init();
    printk("[INIT] page allocator initialized\r\n");
    print_elapsed("kernel memory: ", stage_start);

    stage_start = timer_get_time();
    vfs_init();
    printk("[INIT] vfs initialized\r\n");
    print_elapsed("kernel vfs: ", stage_start);

    stage_start = timer_get_time();
    trap_init();
    syscall_init();
    printk("[INIT] traps initialized\r\n");
    print_elapsed("kernel traps: ", stage_start);

    /* create initial processes */
    printk("[INIT] creating init tasks...\r\n");

    stage_start = timer_get_time();
    dev_init();
    uart_dev_init();
    framebuffer_dev_init();
#if SYS_CORES_PER_CLUSTER > 0
    sys_array_dev_init();
#endif
    timer_init();
     printk("[INIT] switch to uart0\r\n");
    print_elapsed("kernel devices: ", stage_start);
    printk_switch(uart_putc);
    
    stage_start = timer_get_time();
    pipe_init();
    printk("[INIT] pipe initialized\r\n");
    shm_init(kmalloc, kfree);
    printk("[INIT] shm initialized\r\n");
    futex_init();
    printk("[INIT] futex initialized\r\n");
    rcu_init();
    printk("[INIT] rcu initialized\r\n");
    process_init();
    printk("[INIT] process model initialized\r\n");

    smp_init();
    print_elapsed("kernel ipc/process/smp: ", stage_start);

    struct task_struct *init = process_create(init_task, "init", 0);
    if (!init) {
        printk("[KERNEL] cannot create init\r\n");
        while (1) { __asm__ volatile ("wfi"); }
    }
    printk("[KERNEL] init pid=%d\r\n", init->pid);
    print_elapsed("kernel total to shell: ", boot_start);

    sched_set_current(init);
    init->state = TASK_RUNNING;

    /* Bootstrap: switch directly into the first process via context_switch.
     * Use a dummy 'from' context on the kernel stack (we never return here). */
    context_t dummy_from;
    uint8_t *b = (uint8_t *)&dummy_from;
    for (uint32_t i = 0; i < sizeof(context_t); i++) b[i] = 0;
    context_switch(&dummy_from, &init->context);

    while (1) { __asm__ volatile ("wfi"); }
}
