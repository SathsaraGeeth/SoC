#include <stdio.h>
#include <time.h>

unsigned long long get_time(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (unsigned long long)ts.tv_sec * 1000000000ull + (unsigned long long)ts.tv_nsec;
}

int yield(void) {
    return 0;
}

int exec(const char *path) {
    (void)path;
    return -1;
}
