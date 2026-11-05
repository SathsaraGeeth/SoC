/* 
 * kernel/irq/irq.c
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

#include "irq.h"

extern void     irq_disable(void);
extern void     irq_enable(void);
extern uint64_t irq_save(void);
extern void     irq_restore(uint64_t flags);
