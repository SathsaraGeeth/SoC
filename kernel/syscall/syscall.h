/*
 * Comments:
 * 1. API
 * 2. trap/ -> syscall/ -> subsystems (e.g. mm, fs, proc)
 * 3. defines only the syscalls mechanism, implementation is private to the subsystem
 */

#ifndef SYSCALL_H
#define SYSCALL_H

#include <stddef.h>
#include <stdint.h>
#include <trap/trap.h>
#include "syscall_args.h"

typedef int64_t (*syscall_handler_t)(struct trap_frame *tf);

struct syscall_entry {
    uint16_t          number;
    syscall_handler_t handler;
};

extern const struct syscall_entry syscall_table[];
extern const size_t syscall_table_size;

void syscall_init(void);
void syscall_dispatch(struct trap_frame *tf);
void syscall_set_return(struct trap_frame *tf, int64_t value);

#endif /* SYSCALL_H */
