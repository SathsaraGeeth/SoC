#ifndef IRQ_H
#define IRQ_H

#include <stdint.h>

void     irq_disable(void);
void     irq_enable(void);
uint64_t irq_save(void);
void     irq_restore(uint64_t flags);

#endif /* IRQ_H */