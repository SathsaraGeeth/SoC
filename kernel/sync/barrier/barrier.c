/*
 * kernel/sync/barrier/barrier.c
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

#include "barrier.h"

extern void mb(void);
extern void rmb(void);
extern void wmb(void);
extern void smp_mb(void);
extern void smp_rmb(void);
extern void smp_wmb(void);
