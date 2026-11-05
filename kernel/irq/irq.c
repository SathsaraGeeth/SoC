#include "irq.h"

extern void     irq_disable(void);
extern void     irq_enable(void);
extern uint64_t irq_save(void);
extern void     irq_restore(uint64_t flags);
