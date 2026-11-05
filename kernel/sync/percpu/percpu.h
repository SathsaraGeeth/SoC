/*
 * kernel/sync/percpu/percpu.h
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

#ifndef PERCPU_H
#define PERCPU_H

#include <stdint.h>
#include <soc.h>

#define DEFINE_PER_CPU(type, name) type name[THREADS_IN_CLUSTER]
#define DECLARE_PER_CPU(type, name) extern type name[THREADS_IN_CLUSTER]

#define per_cpu(name, cpu)           ((name)[(cpu)])
#define this_cpu_ptr(name)           (&per_cpu((name), percpu_current_cpu()))
#define this_cpu_read(name)          per_cpu((name), percpu_current_cpu())
#define this_cpu_write(name, value)  (per_cpu((name), percpu_current_cpu()) = (value))

uint32_t percpu_current_cpu(void);

#endif /* PERCPU_H */
