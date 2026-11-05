#ifndef FUTEX_H
#define FUTEX_H

#include <stdint.h>

void futex_init(void);
int  futex_wait(volatile uint32_t *address, uint32_t expected);
int  futex_wake(volatile uint32_t *address, uint32_t count);

#endif /* FUTEX_H */
