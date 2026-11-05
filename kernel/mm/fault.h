#ifndef FAULT_H
#define FAULT_H

#include "../proc/sched/sched.h"

void handle_page_fault(context_t *ctx, uint32_t cause);

#endif
