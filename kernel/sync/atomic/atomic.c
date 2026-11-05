#include "atomic.h"

extern int64_t  atomic_read_aint64(const aint64_t *ptr);
extern int32_t  atomic_read_aint32(const aint32_t *ptr);
extern void     atomic_write_aint64(aint64_t *ptr, int64_t value);
extern void     atomic_write_aint32(aint32_t *ptr, int32_t value);
extern int64_t  atomic_add_aint64(aint64_t *ptr, int64_t value);
extern int32_t  atomic_add_aint32(aint32_t *ptr, int32_t value);
extern int64_t  atomic_cmpxchg_aint64(aint64_t *ptr, int64_t expected, int64_t desired);
extern int32_t  atomic_cmpxchg_aint32(aint32_t *ptr, int32_t expected, int32_t desired);
