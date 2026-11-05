#include "percpu.h"
#include "../../smp/smp.h"

uint32_t percpu_current_cpu(void) {
    return smp_get_tid();
}
