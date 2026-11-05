#include <syscall/syscall.h>
#include <syscall/usercopy.h>
#include <proc/sched/pid.h>
#include <mm/frame.h>
#include <mm/page.h>
#include <soc.h>
#include "../../user/include/sys/dmctp.h"

int64_t sys_getcpu(struct trap_frame *frame)
{
    (void)frame;
    return sched_cpu();
}

int64_t sys_uname(struct trap_frame *frame)
{
    static const char name[] = "DMCTP";
    return copy_to_user((void *)syscall_arg(frame, 0), name, sizeof(name));
}

int64_t sys_getrandom(struct trap_frame *frame)
{
    uint8_t bytes[64];
    size_t requested = syscall_arg(frame, 1);
    size_t done = 0;
    uint64_t state = frame->sepc ^ frame->sstatus ^ (uintptr_t)current;
    while (done < requested) {
        size_t chunk = requested - done;
        size_t index;
        if (chunk > sizeof(bytes)) chunk = sizeof(bytes);
        for (index = 0; index < chunk; ++index) {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            bytes[index] = (uint8_t)state;
        }
        if (copy_to_user((void *)(syscall_arg(frame, 0) + done),
                         bytes, chunk) < 0)
            return -1;
        done += chunk;
    }
    return (int64_t)done;
}

int64_t sys_sysinfo(struct trap_frame *frame)
{
    dmctp_sysinfo_t info = {0};
    frame_stats(&info.total_frames, &info.free_frames);
    info.page_size = PAGE_SIZE;
    info.clusters = NUM_CLUSTERS;
    info.threads_per_cluster = THREADS_IN_CLUSTER;
    info.mesh_coord_bits = MESH_COORD_BITS;
    info.memory_regions = NUM_REGIONS;
    info.ram_per_region = RAM_SIZE;
    info.process_count = task_count();
    info.process_limit = PROC_MAX_TASKS;
    info.sys_cores_per_cluster = SYS_CORES_PER_CLUSTER;
    info.sys_array_arch = SYS_ARRAY_MAC_T;
    info.sys_array_m = SYS_ARRAY_M;
    info.sys_array_max_dense = SYS_ARRAY_MAX_DENSE_MAT_SZ;
    info.cpu_count = NUM_CLUSTERS * THREADS_IN_CLUSTER;
    info.sys_core_count = NUM_CLUSTERS * SYS_CORES_PER_CLUSTER;
    return copy_to_user((void *)syscall_arg(frame, 0), &info, sizeof(info));
}
