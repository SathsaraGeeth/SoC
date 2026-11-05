/*
 * Comments:
 * 1. Implement the context switching for the arch
 */

#include "sched.h"

extern void context_switch(context_t *from, context_t *to);

void switch_to(struct task_struct *prev, struct task_struct *next)
{
    if (!next || prev == next)
        return;
    if (!prev) {
        context_t bootstrap;
        unsigned char *byte = (unsigned char *)&bootstrap;
        size_t size = sizeof(bootstrap);
        while (size--)
            *byte++ = 0;
        context_switch(&bootstrap, &next->context);
        return;
    }
    context_switch(&prev->context, &next->context);
}
