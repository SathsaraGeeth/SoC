#include <syscall/syscall.h>
#include "timer.h"

int64_t sys_clock_gettime(struct trap_frame *frame)
{
    (void)frame;
    return (int64_t)timer_get_time();
}

int64_t sys_nanosleep(struct trap_frame *frame)
{
    uint64_t duration = syscall_arg(frame, 0);
    uint64_t deadline = timer_get_time() + duration;
    while (timer_get_time() < deadline)
        __asm__ volatile ("wfi");
    return 0;
}

int64_t sys_timer_create(struct trap_frame *frame) { (void)frame; return -1; }
int64_t sys_timer_delete(struct trap_frame *frame) { (void)frame; return -1; }
