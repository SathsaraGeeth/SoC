#include <syscall/syscall.h>
#include <proc/process.h>
#include <mm/mapping.h>
#include <mm/page.h>

int64_t sys_mmap(struct trap_frame *frame)
{
    addr_t address = syscall_arg(frame, 0);
    size_t length = syscall_arg(frame, 1);
    uint32_t protection = (uint32_t)syscall_arg(frame, 2);
    uint32_t flags = (uint32_t)syscall_arg(frame, 3);
    int fd = (int)syscall_arg(frame, 4);
    addr_t offset = syscall_arg(frame, 5);
    int slot = -1;
    int index;

    if (!current || !length)
        return -1;
    length = (length + PAGE_SIZE - 1) & ~(size_t)(PAGE_SIZE - 1);
    if (!length)
        return -1;
    if (!address) {
        address = USER_MMAP_BASE;
        for (index = 0; index < MAX_VMAS; ++index)
            if (current->mm->vmas[index].used &&
                current->mm->vmas[index].vaddr_start >= address)
                address = current->mm->vmas[index].vaddr_end;
    }
    if (address != mapping_local_addr(address) ||
        (address & (PAGE_SIZE - 1)) ||
        !mapping_user_range_valid(address, length))
        return -1;
    for (index = 0; index < MAX_VMAS; ++index)
        if (!current->mm->vmas[index].used) {
            slot = index;
            break;
        }
    if (slot < 0)
        return -1;
    current->mm->vmas[slot].used = 1;
    current->mm->vmas[slot].vaddr_start = address;
    current->mm->vmas[slot].vaddr_end = address + length;
    current->mm->vmas[slot].prot = protection;
    current->mm->vmas[slot].flags = flags;
    current->mm->vmas[slot].fd = fd;
    current->mm->vmas[slot].offset = offset;
    current->mm->vmas[slot].file_size = 0;
    return (int64_t)address;
}

int64_t sys_munmap(struct trap_frame *frame)
{
    addr_t address = syscall_arg(frame, 0);
    size_t length = syscall_arg(frame, 1);
    int index;
    length = (length + PAGE_SIZE - 1) & ~(size_t)(PAGE_SIZE - 1);
    for (index = 0; index < MAX_VMAS; ++index) {
        vma_t *vma = &current->mm->vmas[index];
        if (vma->used && vma->vaddr_start == address &&
            vma->vaddr_end == address + length) {
            mapping_free_vma(current->mm, vma);
            vma->used = 0;
            return 0;
        }
    }
    return -1;
}

int64_t sys_mprotect(struct trap_frame *frame)
{
    addr_t address = syscall_arg(frame, 0);
    size_t length = syscall_arg(frame, 1);
    uint32_t protection = (uint32_t)syscall_arg(frame, 2);
    int index;
    length = (length + PAGE_SIZE - 1) & ~(size_t)(PAGE_SIZE - 1);
    for (index = 0; index < MAX_VMAS; ++index) {
        vma_t *vma = &current->mm->vmas[index];
        if (vma->used && vma->vaddr_start == address &&
            vma->vaddr_end == address + length) {
            vma->prot = protection;
            mapping_activate(current->mm);
            return 0;
        }
    }
    return -1;
}

int64_t sys_brk(struct trap_frame *frame)
{
    (void)frame;
    return -1;
}
