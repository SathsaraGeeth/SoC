/*
 * kernel/sync/lockdep/lockdep.c
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

#include "lockdep.h"
#include <percpu.h>

void lockdep_init(lockdep_map_t *map, const char *name) {
    map->name = name;
    spinlock_init(&map->guard);
    map->owner = LOCKDEP_NO_OWNER;
    map->held = 0;
}

int lockdep_acquire(lockdep_map_t *map) {
    uint32_t cpu = percpu_current_cpu();
    int valid = 1;

    spinlock_lock(&map->guard);
    if (map->held && map->owner == cpu) {
        valid = 0;
    } else {
        map->owner = cpu;
        map->held = 1;
    }
    spinlock_unlock(&map->guard);
    return valid;
}

int lockdep_release(lockdep_map_t *map) {
    uint32_t cpu = percpu_current_cpu();
    int valid = 1;

    spinlock_lock(&map->guard);
    if (!map->held || map->owner != cpu) {
        valid = 0;
    } else {
        map->owner = LOCKDEP_NO_OWNER;
        map->held = 0;
    }
    spinlock_unlock(&map->guard);
    return valid;
}

int lockdep_is_held(const lockdep_map_t *map) {
    return map->held && map->owner == percpu_current_cpu();
}
