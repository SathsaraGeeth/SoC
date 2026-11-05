#ifndef DMCTP_SYS_DMCTP_H
#define DMCTP_SYS_DMCTP_H

#include <stdint.h>

#define DMCTP_NAME_MAX 32

typedef struct {
    char name[DMCTP_NAME_MAX];
    uint32_t type;
    uint32_t size;
} dmctp_dirent_t;

typedef struct {
    uint32_t total_frames;
    uint32_t free_frames;
    uint32_t page_size;
    uint32_t clusters;
    uint32_t threads_per_cluster;
    uint32_t mesh_coord_bits;
    uint32_t memory_regions;
    uint32_t ram_per_region;
    uint32_t process_count;
    uint32_t process_limit;
    uint32_t sys_cores_per_cluster;
    uint32_t sys_array_arch;
    uint32_t sys_array_m;
    uint32_t sys_array_max_dense;
    uint32_t cpu_count;
    uint32_t sys_core_count;
} dmctp_sysinfo_t;

typedef struct {
    int32_t pid;
    int32_t ppid;
    uint32_t state;
    char name[16];
} dmctp_procinfo_t;

#define DMCTP_PROC_READY   0
#define DMCTP_PROC_RUNNING 1
#define DMCTP_PROC_ZOMBIE  2
#define DMCTP_PROC_DEAD    3
#define DMCTP_PROC_BLOCKED 4

#define DMCTP_SYS_ARRAY_MAC20I 0
#define DMCTP_SYS_ARRAY_MACFP8 1
#define DMCTP_SYS_ARRAY_MACFP8INT8 2

#endif
