/*
 * kernel/sync/bitops/bitops.h
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

#ifndef BITOPS_H
#define BITOPS_H

#include <stdint.h>


void set_bit(uint64_t bit, volatile uint64_t *addr);
void clear_bit(uint64_t bit, volatile uint64_t *addr);
int  test_bit(uint64_t bit, volatile uint64_t *addr);
int  test_and_set_bit(uint64_t bit, volatile uint64_t *addr);
int  test_and_clear_bit(uint64_t bit, volatile uint64_t *addr);
int  test_and_change_bit(uint64_t bit, volatile uint64_t *addr);


#endif /* BITOPS_H */