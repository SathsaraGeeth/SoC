#include <stdint.h>
#include <sys/mman.h>
#include <unistd.h>

#define PAGE_SIZE 4096u

int main(void) {
    volatile uint64_t *pages;
    uint64_t value;

    puts("--- Page Fault Test ---\n");

    pages = mmap(0, 2 * PAGE_SIZE, PROT_READ | PROT_WRITE,
                 MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (pages == MAP_FAILED) {
        puts("FAIL: mmap\n");
        return 1;
    }

    puts("Triggering store page fault...\n");
    pages[0] = UINT64_C(0x123456789abcdef0);

    puts("Triggering load page fault...\n");
    value = pages[PAGE_SIZE / sizeof(*pages)];

    if (pages[0] != UINT64_C(0x123456789abcdef0) || value != 0) {
        puts("FAIL: page contents\n");
        return 1;
    }

    if (munmap((void *)pages, 2 * PAGE_SIZE) != 0) {
        puts("FAIL: munmap\n");
        return 1;
    }

    puts("PASS: page faults resolved\n");
    return 0;
}
