/*
 * kernel/syscall/syscall_args.h
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

/*
 * Comments:
 * 1. Dependent of the function ABI of the isa
 */

#ifndef SYSCALL_ARGS_H
#define SYSCALL_ARGS_H

#include <stdint.h>
#include <trap/trap.h>

struct trap_frame;

static inline uint64_t syscall_arg(struct trap_frame *tf, int index) {
    switch(index) {
    case 0:  return tf->r11;
    case 1:  return tf->r12;
    case 2:  return tf->r13;
    case 3:  return tf->r14;
    case 4:  return tf->r15;
    case 5:  return tf->r16;
    default: return 0;
    }
}


static inline int64_t syscall_arg_int(struct trap_frame *tf,int index) {
    return (int64_t)syscall_arg(tf,index);
}


static inline uintptr_t syscall_arg_ptr(struct trap_frame *tf, int index) {
    return (uintptr_t)syscall_arg(tf,index);
}


#endif
