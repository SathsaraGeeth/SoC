/*
 * kernel/sync/lockdep/lockdep.h
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

#ifndef LOCKDEP_H
#define LOCKDEP_H

#include <stdint.h>
#include <spinlock.h>

#define LOCKDEP_NO_OWNER UINT32_MAX

typedef struct lockdep_map {
    const char *name;
    spinlock_t   guard;
    uint32_t     owner;
    uint32_t     held;
} lockdep_map_t;

void lockdep_init(lockdep_map_t *map, const char *name);
int  lockdep_acquire(lockdep_map_t *map);
int  lockdep_release(lockdep_map_t *map);
int  lockdep_is_held(const lockdep_map_t *map);

#endif /* LOCKDEP_H */
