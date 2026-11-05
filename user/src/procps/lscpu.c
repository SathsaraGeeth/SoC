#include <unistd.h>
int main(void) {
    dmctp_sysinfo_t info;
    if (sysinfo(&info) < 0) { puts("lscpu: sysinfo failed\n"); return 1; }
    unsigned clusters = info.clusters;
    unsigned cpu_per_cluster = info.threads_per_cluster;
    unsigned total_cpus = info.cpu_count;
    unsigned sys_per_cluster = info.sys_cores_per_cluster;
    unsigned total_sys_cores = info.sys_core_count;
    const char *arch = info.sys_array_arch == DMCTP_SYS_ARRAY_MAC20I
        ? "int8i.int32i.int8i" : info.sys_array_arch == DMCTP_SYS_ARRAY_MACFP8
        ? "fp8.fp32.fp8" : info.sys_array_arch == DMCTP_SYS_ARRAY_MACFP8INT8
        ? "fp8&int8.runtime" : "unknown";
    puts("Architecture:    dmctp SoC\n");
    puts("CPU Arch:        dmctp64\n");
    printf("Clusters:        %u\nThreads/Clus:    %u\nTotal CPUs:      %u\nSys Cores/Clus:  %u\nTotal Sys Cores: %u\n",
           clusters, cpu_per_cluster, total_cpus, sys_per_cluster, total_sys_cores);
    printf("Sys Core Arch:   %s | native: %ux%u | dense: %ux%u\n",
           arch, info.sys_array_m, info.sys_array_m,
           info.sys_array_max_dense, info.sys_array_max_dense);
    return 0;
}
