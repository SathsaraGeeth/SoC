#include <stdlib.h>
#include <sys/mman.h>

#define PAGE_SIZE 4096u
#define ALLOC_MAGIC 0x444d414cu

typedef struct {
    unsigned length;
    unsigned magic;
} alloc_header_t;

void *malloc(size_t size) {
    if (size == 0 || size > 0xffffffffu - sizeof(alloc_header_t)) return 0;

    unsigned length = (unsigned)size + sizeof(alloc_header_t);
    length = (length + PAGE_SIZE - 1u) & ~(PAGE_SIZE - 1u);
    void *base = mmap(0, length, PROT_READ | PROT_WRITE,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (base == MAP_FAILED) return 0;

    alloc_header_t *header = (alloc_header_t *)base;
    header->length = length;
    header->magic = ALLOC_MAGIC;
    return header + 1;
}

void free(void *ptr) {
    if (!ptr) return;
    alloc_header_t *header = ((alloc_header_t *)ptr) - 1;
    if (header->magic != ALLOC_MAGIC) return;
    header->magic = 0;
    (void)munmap(header, header->length);
}
