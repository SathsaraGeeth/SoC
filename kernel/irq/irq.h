/* 
 * kernel/irq/irq.h
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

#ifndef IRQ_H
#define IRQ_H

#include <stdint.h>

void     irq_disable(void);
void     irq_enable(void);
uint64_t irq_save(void);
void     irq_restore(uint64_t flags);

#endif /* IRQ_H */