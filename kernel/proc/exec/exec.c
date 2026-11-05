#include "exec.h"
#include "../process.h"
#include "../signal/signal.h"
#include "../../fs/file.h"
#include "../../lib/printk.h"
#include "../../mm/page.h"
#include "../../mm/slab.h"
#include <regs.h>

#define EI_NIDENT 16
#define PT_LOAD 1
#define PF_X 1
#define PF_W 2
#define PF_R 4

struct elf64_header {
    unsigned char ident[EI_NIDENT];
    uint16_t type;
    uint16_t machine;
    uint32_t version;
    uint64_t entry;
    uint64_t phoff;
    uint64_t shoff;
    uint32_t flags;
    uint16_t ehsize;
    uint16_t phentsize;
    uint16_t phnum;
    uint16_t shentsize;
    uint16_t shnum;
    uint16_t shstrndx;
};

struct elf64_program_header {
    uint32_t type;
    uint32_t flags;
    uint64_t offset;
    uint64_t vaddr;
    uint64_t paddr;
    uint64_t filesz;
    uint64_t memsz;
    uint64_t align;
};

static void zero_memory(void *pointer, size_t size)
{
    unsigned char *byte = pointer;
    while (size--)
        *byte++ = 0;
}

static int free_vma_slot(mm_t *mm)
{
    int index;
    for (index = 0; index < MAX_VMAS; ++index)
        if (!mm->vmas[index].used)
            return index;
    return -1;
}

static int load_elf_binary(mm_t *new_mm, const char *path, uintptr_t *entry,
                           uintptr_t *stack_top)
{
    struct elf64_header header;
    file_t *file;
    vnode_t *node;
    uint32_t position = 0;
    int fd;
    uint32_t index;

    fd = process_open(path, O_RDONLY);
    if (fd < 0) {
        printk("[EXEC] open failed: %s\r\n", path);
        return -1;
    }
    file = fd_get(current->files, fd);
    node = file ? file->vnode : 0;
    if (!node || !node->ops || !node->ops->read ||
        node->ops->read(node, &header, sizeof(header), &position) !=
            (int)sizeof(header))
        { printk("[EXEC] short ELF header: %s\r\n", path); goto fail; }
    if (header.ident[0] != 0x7f || header.ident[1] != 'E' ||
        header.ident[2] != 'L' || header.ident[3] != 'F' ||
        header.ident[4] != 2 || header.machine != 243 ||
        header.ehsize != sizeof(header) ||
        header.phentsize != sizeof(struct elf64_program_header) ||
        header.phoff > UINT32_MAX ||
        !mapping_user_range_valid(header.entry, 1))
        { printk("[EXEC] invalid ELF header: %s\r\n", path); goto fail; }

    for (index = 0; index < header.phnum; ++index) {
        struct elf64_program_header program;
        uint32_t at = (uint32_t)header.phoff +
            index * (uint32_t)header.phentsize;
        int slot;
        if (node->ops->read(node, &program, sizeof(program), &at) !=
            (int)sizeof(program))
            { printk("[EXEC] bad program header: %s\r\n", path); goto fail; }
        if (program.type != PT_LOAD || !program.memsz)
            continue;
        if (program.offset > UINT32_MAX ||
            !mapping_user_range_valid(program.vaddr, program.memsz))
            { printk("[EXEC] invalid load segment: %s\r\n", path); goto fail; }
        slot = free_vma_slot(new_mm);
        if (slot < 0)
            { printk("[EXEC] no VMA for segment: %s\r\n", path); goto fail; }
        new_mm->vmas[slot].vaddr_start = program.vaddr & ~(addr_t)0xfff;
        new_mm->vmas[slot].vaddr_end =
            (program.vaddr + program.memsz + 0xfff) & ~(addr_t)0xfff;
        new_mm->vmas[slot].prot =
            ((program.flags & PF_R) ? PROT_READ : 0) |
            ((program.flags & PF_W) ? PROT_WRITE : 0) |
            ((program.flags & PF_X) ? PROT_EXEC : 0);
        new_mm->vmas[slot].flags = MAP_PRIVATE;
        new_mm->vmas[slot].fd = fd;
        new_mm->vmas[slot].offset = program.offset;
        new_mm->vmas[slot].file_size = program.filesz;
        new_mm->vmas[slot].used = 1;
    }

    {
        int slot = free_vma_slot(new_mm);
        if (slot < 0)
            { printk("[EXEC] no VMA for stack: %s\r\n", path); goto fail; }
        new_mm->vmas[slot].vaddr_start =
            USER_STACK_TOP - USER_STACK_SIZE;
        new_mm->vmas[slot].vaddr_end = USER_STACK_TOP;
        new_mm->vmas[slot].prot = PROT_READ | PROT_WRITE;
        new_mm->vmas[slot].flags = MAP_PRIVATE | MAP_ANONYMOUS;
        new_mm->vmas[slot].fd = -1;
        new_mm->vmas[slot].offset = 0;
        new_mm->vmas[slot].file_size = 0;
        new_mm->vmas[slot].used = 1;
    }
    *entry = header.entry;
    *stack_top = USER_STACK_TOP;
    return 0; /* The executable fd remains pinned by its VMAs. */

fail:
    process_close(fd);
    return -1;
}

static void set_comm(struct task_struct *task, const char *path)
{
    const char *base = path;
    const char *cursor = path;
    uint32_t index = 0;
    while (*cursor) {
        if (*cursor == '/')
            base = cursor + 1;
        ++cursor;
    }
    while (base[index] && index + 1 < PROC_TASK_NAME_LEN) {
        task->comm[index] = base[index];
        ++index;
    }
    task->comm[index] = '\0';
}

int do_execve(context_t *frame, const char *path, const char *const argv[],
              const char *const envp[])
{
    uintptr_t entry;
    uintptr_t stack_top;
    uintptr_t stack_address;
    vma_t *stack_vma;
    mm_t new_mm;
    pte_slot_t *old_page_map;
    uintptr_t old_asid;
    uintptr_t restore_frame;
    int index;
    (void)argv;
    (void)envp;

    if (!current || !frame || !path || !*path)
        return -1;
    zero_memory(&new_mm, sizeof(new_mm));
    old_asid = current->mm->asid;
    new_mm.asid = old_asid;
    if (load_elf_binary(&new_mm, path, &entry, &stack_top) < 0)
        return -1;

    /* Commit only after the replacement image has passed all validation. */
    old_page_map = current->mm->page_map;
    for (index = 0; index < MAX_VMAS; ++index) {
        if (current->mm->vmas[index].used) {
            mapping_free_vma(current->mm, &current->mm->vmas[index]);
            current->mm->vmas[index].used = 0;
        }
    }
    /* The process keeps the same mm owner and ASID across exec.  Reuse its
     * fixed-size sparse PTE table instead of returning it to the simple slab
     * allocator and allocating another table during prefaulting. */
    if (old_page_map) {
        for (index = 0; index < MAX_SW_PTES; ++index) {
            old_page_map[index].vpn_plus_one = 0;
            old_page_map[index].pte = 0;
        }
    }
    new_mm.page_map = old_page_map;
    *current->mm = new_mm;

    /* Keep the architecture's trap-return selection metadata.  The general
     * registers are replaced by exec, but the active kernel trap frame is
     * still the frame through which this syscall must return. */
    restore_frame = frame->restore_frame;
    zero_memory(frame, sizeof(*frame));
    frame->r2 = stack_top;
    frame->sepc = entry;
    frame->sstatus = SSTATUS_SPP_U | SSTATUS_SPIE;
    frame->restore_frame = restore_frame;
    current->context = *frame;
    signal_exec_reset(current);
    set_comm(current, path);

    for (index = 0; index < MAX_VMAS; ++index) {
        vma_t *vma = &current->mm->vmas[index];
        uintptr_t vpn;
        uintptr_t last;
        if (!vma->used || !(vma->prot & PROT_EXEC))
            continue;
        vpn = vma->vaddr_start >> PAGE_SHIFT;
        last = (vma->vaddr_end + PAGE_SIZE - 1) >> PAGE_SHIFT;
        while (vpn < last) {
            page_resolve_fault(current->mm, vma, vpn, 12);
            ++vpn;
        }
    }
    stack_address = stack_top - sizeof(uintptr_t);
    stack_vma = mapping_find_vma(current->mm, stack_address);
    if (stack_vma)
        page_resolve_fault(current->mm, stack_vma,
                           stack_address >> PAGE_SHIFT, 13);
    return 0;
}

int do_exec(context_t *frame, const char *path)
{
    return do_execve(frame, path, 0, 0);
}
