/*
 * kernel/sync/percpu/percpu.c
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

#include "percpu.h"
#include "../../smp/smp.h"

uint32_t percpu_current_cpu(void) {
    return smp_get_tid();
}
