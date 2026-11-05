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
