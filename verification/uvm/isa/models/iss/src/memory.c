#include "include/memory_backend.h"
#include "isa_generated.h"

#include <stdio.h>
#include <stdlib.h>

enum {
    ISS_MEMORY_WORD_BYTES = sizeof(uint64_t),
    ISS_MEMORY_PAGE_SHIFT = 12,
    ISS_MEMORY_PAGE_SIZE = 1u << ISS_MEMORY_PAGE_SHIFT,
    ISS_MEMORY_WORDS_PER_PAGE = ISS_MEMORY_PAGE_SIZE / ISS_MEMORY_WORD_BYTES
};

typedef struct memory_page {
    uint64_t base;
    mem_t words[ISS_MEMORY_WORDS_PER_PAGE];
    struct memory_page *next;
} memory_page_t;

struct iss_memory_backend {
    memory_page_t *pages;
};

static uint64_t aligned_address(uint64_t address)
{
    return address & ~((uint64_t)ISS_MEMORY_WORD_BYTES - UINT64_C(1));
}

static uint64_t page_base(uint64_t address)
{
    return address & ~((uint64_t)ISS_MEMORY_PAGE_SIZE - UINT64_C(1));
}

static memory_page_t *find_page(iss_memory_backend_t *backend,
                                uint64_t address)
{
    memory_page_t *page;
    const uint64_t base = page_base(address);

    for (page = backend->pages; page != NULL; page = page->next) {
        if (page->base == base) {
            return page;
        }
    }

    return NULL;
}

static memory_page_t *get_page(iss_memory_backend_t *backend,
                               uint64_t address)
{
    memory_page_t *page = find_page(backend, address);

    if (page != NULL) {
        return page;
    }

    page = (memory_page_t *)calloc(1, sizeof(*page));
    if (page == NULL) {
        return NULL;
    }

    page->base = page_base(address);
    page->next = backend->pages;
    backend->pages = page;
    return page;
}

static mem_t *find_word(iss_memory_backend_t *backend,
                               uint64_t address)
{
    memory_page_t *page = find_page(backend, address);
    const size_t index = (size_t)((aligned_address(address) -
                                   page_base(address)) /
                                  ISS_MEMORY_WORD_BYTES);

    return page == NULL ? NULL : &page->words[index];
}

static mem_t *get_word(iss_memory_backend_t *backend,
                              uint64_t address)
{
    memory_page_t *page = get_page(backend, address);
    const size_t index = (size_t)((aligned_address(address) -
                                   page_base(address)) /
                                  ISS_MEMORY_WORD_BYTES);

    return page == NULL ? NULL : &page->words[index];
}

static uint8_t read_byte(iss_memory_backend_t *backend, uint64_t address)
{
    const mem_t *word = find_word(backend, address);
    const unsigned shift = (unsigned)(address % ISS_MEMORY_WORD_BYTES) * 8u;

    return word == NULL ? 0 : (uint8_t)(word->value >> shift);
}

static void write_byte(iss_memory_backend_t *backend, uint64_t address,
                       uint8_t value, int invalidate_lock)
{
    mem_t *word = get_word(backend, address);
    const unsigned shift = (unsigned)(address % ISS_MEMORY_WORD_BYTES) * 8u;
    const uint64_t mask = UINT64_C(0xff) << shift;

    if (word == NULL) {
        return;
    }

    word->value = (word->value & ~mask) | ((uint64_t)value << shift);
    if (invalidate_lock) {
        word->locked = 0;
    }
}

uint64_t iss_memory_read(iss_memory_backend_t *backend,
                         uint64_t address, unsigned bytes)
{
    uint64_t value = 0;
    unsigned index;

    for (index = 0; index < bytes; ++index) {
        value |= (uint64_t)read_byte(backend, address + index) <<
                 (index * 8u);
    }

    return value;
}

void iss_memory_write(iss_memory_backend_t *backend,
                      uint64_t address, uint64_t value, unsigned bytes)
{
    unsigned index;

    for (index = 0; index < bytes; ++index) {
        write_byte(backend, address + index,
                   (uint8_t)(value >> (index * 8u)), 1);
    }
}

void iss_memory_release(iss_memory_backend_t *backend, uint32_t owner)
{
    memory_page_t *page;

    for (page = backend->pages; page != NULL; page = page->next) {
        size_t index;

        for (index = 0; index < ISS_MEMORY_WORDS_PER_PAGE; ++index) {
            mem_t *word = &page->words[index];

            if (word->locked && word->owner == owner) {
                word->locked = 0;
            }
        }
    }
}

void iss_memory_reserve(iss_memory_backend_t *backend,
                        uint32_t owner, uint64_t address)
{
    mem_t *word;

    iss_memory_release(backend, owner);
    word = get_word(backend, address);
    if (word == NULL) {
        return;
    }

    word->owner = owner;
    word->locked = 1;
}

int iss_memory_store_conditional(iss_memory_backend_t *backend,
                                 uint32_t owner, uint64_t address,
                                 uint64_t value, unsigned bytes)
{
    mem_t *word = find_word(backend, address);
    const int success = word != NULL && word->locked &&
                        word->owner == owner;

    iss_memory_release(backend, owner);
    if (success) {
        iss_memory_write(backend, address, value, bytes);
    }

    return success;
}

static int load_image(iss_memory_backend_t *backend, const char *image_path)
{
    FILE *image;
    uint8_t buffer[ISS_MEMORY_PAGE_SIZE];
    uint64_t address = 0;
    size_t count;

    image = fopen(image_path, "rb");
    if (image == NULL) {
        return -1;
    }

    while ((count = fread(buffer, 1, sizeof(buffer), image)) != 0) {
        size_t index;

        for (index = 0; index < count; ++index) {
            write_byte(backend, address + index, buffer[index], 0);
        }
        address += count;
    }

    if (ferror(image)) {
        fclose(image);
        return -1;
    }

    fclose(image);
    return 0;
}

int iss_memory_backend_create(const char *image_path,
                              iss_memory_backend_t **backend_out)
{
    iss_memory_backend_t *backend;

    if (backend_out == NULL || image_path == NULL || image_path[0] == '\0') {
        return -1;
    }

    backend = (iss_memory_backend_t *)calloc(1, sizeof(*backend));
    if (backend == NULL) {
        return -1;
    }

    if (load_image(backend, image_path) != 0) {
        iss_memory_backend_destroy(backend);
        return -1;
    }

    *backend_out = backend;
    return 0;
}

void iss_memory_backend_destroy(iss_memory_backend_t *backend)
{
    memory_page_t *page;

    if (backend == NULL) {
        return;
    }

    page = backend->pages;
    while (page != NULL) {
        memory_page_t *next = page->next;

        free(page);
        page = next;
    }

    free(backend);
}

mem_t *iss_memory_view(iss_memory_backend_t *backend)
{
    return find_word(backend, 0);
}
