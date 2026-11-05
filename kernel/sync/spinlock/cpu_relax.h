/*
 * kernel/sync/spinlock/cpu_relax.S
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

#ifndef CPU_RELAX_H
#define CPU_RELAX_H

static inline void cpu_relax(void) {
    asm volatile(
        "nop"
        :
        :
        : "memory"
    );
}
#endif /* CPU_RELAX_H */
