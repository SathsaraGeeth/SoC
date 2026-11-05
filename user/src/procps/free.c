#include <unistd.h>
int main(void) {
    dmctp_sysinfo_t info;
    if (sysinfo(&info) < 0) { puts("free: sysinfo failed\n"); return 1; }
    printf("Memory Regions: %u\n", info.memory_regions);
    printf("RAM per region: %u bytes\n", info.ram_per_region);
    printf("Total RAM:      %u bytes\n",
           info.memory_regions * info.ram_per_region);
    printf("\nprocs:  %u / %u\n", info.process_count, info.process_limit);
    puts("heap:   slab allocator active\n");
    return 0;
}
