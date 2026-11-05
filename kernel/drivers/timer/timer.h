#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>
#include "../../proc/sched/sched.h"

#include <soc.h>

void timer_init(void);
void timer_handle_irq(context_t *ctx);
uint64_t timer_get_time(void);

#endif
