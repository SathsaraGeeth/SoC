#ifndef SMP_H
#define SMP_H

#include <stdint.h>
#include <soc.h>
#include <regs.h>
// #include <nom.h>
#include "../mm/heap.h"


extern void smp_set_entry(uint32_t tid, void (*entry)(void));
extern void smp_set_release(uint32_t tid);
extern void smp_set_stack(uint32_t tid, uint32_t stack);

void smp_init(void);

#endif
