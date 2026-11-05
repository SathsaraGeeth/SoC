/* 
 * /sync/spinlock.c
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

#include "spinlock.h"
#include <regs.h>

void spin_lock(spinlock_t *lock) {
    while (1) {
        uint32_t tmp = load_reserved(&lock->lock);
        if (tmp == SPINLOCK_UNLOCKED) {
            if (store_conditional(&lock->lock, SPINLOCK_LOCKED) == 0) {
                __asm__ volatile ("fence rw, rw" ::: "memory");
                break;
            }
        }
    }
}

void spin_unlock(spinlock_t *lock) {
    __asm__ volatile ("" ::: "memory");
    lock->lock = SPINLOCK_UNLOCKED;
}
