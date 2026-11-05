/*
 * Comments:
 * 1. Abstracts the ISA
 *      i.   CPU State
 *      ii.  Memory State
 *      iii. Transforms of those states (called instructions)
 *    Fully describes the ISA
 * 2. ISS simulates the ISA thus,
 *    ISS is a concrete implementation of the ISA
 */

#ifndef DMCTP_ISA_H
#define DMCTP_ISA_H

#include <stdint.h>

#include "cpu.h"
#include "memory.h"

struct isa {
    cpu_t               cpu;
    mem_t               *memory;
    const cpu_methods_t *cpu_methods;
    const mem_methods_t *mem_methods;
};

#endif
