/*
 * kernel/syscall/syscall.c
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

#include "syscall.h"
#include <proc/process.h>
#include <lib/printk.h>

#define DBG_PRINT_EN 0

#ifdef  KERNEL_SYSCALL_DBG
#undef  DBG_PRINT_EN
#define DBG_PRINT_EN 1
#include <lib/printk.h>
#endif

void syscall_init(void) {
    if (DBG_PRINT_EN) {
        printk("[SYS] syscall_init()\r\n");
    }
}

void syscall_set_return(struct trap_frame *frame, int64_t value) {
    if (DBG_PRINT_EN) {
        printk("[SYS] syscall_set_return() value=%ld\r\n", value);
    }
    frame->r10 = (uint64_t)value;
}

void syscall_dispatch(struct trap_frame *frame) {
    struct task_struct *caller = current;
    uint16_t number;
    size_t index;

    if (!frame)
        return;
    process_reap_deferred();

    number = (uint16_t)frame->r10;
    for (index = 0; index < syscall_table_size; ++index) {
        if (syscall_table[index].number == number) {
            int64_t result = syscall_table[index].handler(frame);

            if (caller && current == caller) {
                syscall_set_return(frame, result);
                caller->context = *frame;
            }
            if (DBG_PRINT_EN) {
                printk("[SYS] syscall_dispatch() number=0x%x result=%ld\r\n", number, result);
            }

            return;
        }
    }
    printk("[SYS] unknown syscall 0x%x\r\n", number);
    syscall_set_return(frame, -1);
}
