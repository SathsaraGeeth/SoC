/*
 * kernel/trap/trap.c
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

#include <trap/trap.h>

#include <drivers/timer/timer.h>
#include <mm/fault.h>
#include <syscall/syscall.h>
#include <regs.h>

#define DBG_PRINT_EN 0

#ifdef  KERNEL_TRAP_DBG
#undef  DBG_PRINT_EN
#define DBG_PRINT_EN 1
#include <lib/printk.h>
#endif

/*
 * implemented in trap/entry.S
 */
extern void _supervisor_trap_vector(void);

void trap_init(void) {
    uintptr_t vector = (uintptr_t)_supervisor_trap_vector;

    csr_write(CSR_SSCRATCH, 0);
    csr_write(CSR_STVEC, vector | TVEC_MODE_VECTORED);
}

void trap_dispatch(struct trap_frame *tf) {
    uint64_t cause = tf->scause;

#if DBG_PRINT_EN
    if (cause == CAUSE_FETCH_PAGE_FAULT) {
        printk("[TRAP] cause=CAUSE_FETCH_PAGE_FAULT (instruction page fault) raw=0x%x pc=0x%x address=0x%x\r\n", cause, tf->sepc, tf->stval);
    } else if (cause == CAUSE_LOAD_PAGE_FAULT) {
        printk("[TRAP] cause=CAUSE_LOAD_PAGE_FAULT (load page fault) raw=0x%x pc=0x%x address=0x%x\r\n", cause, tf->sepc, tf->stval);
    } else if (cause == CAUSE_STORE_PAGE_FAULT) {
        printk("[TRAP] cause=CAUSE_STORE_PAGE_FAULT (store page fault) raw=0x%x pc=0x%x address=0x%x\r\n", cause, tf->sepc, tf->stval);
    } else {
        printk("[TRAP] cause=%s (%s) raw=0x%x pc=0x%x\r\n", trap_cause_name(cause), trap_cause_str(cause), cause, tf->sepc);
    }
#endif

    if (cause == CAUSE_IRQ_S_TIMER) {
        timer_handle_irq(tf);
    } else if (cause == CAUSE_ECALL_U || cause == CAUSE_ECALL_S || cause == CAUSE_ECALL_M) {
        tf->sepc += 4;
        syscall_dispatch(tf);
    } else if (cause == CAUSE_FETCH_PAGE_FAULT || cause == CAUSE_LOAD_PAGE_FAULT || cause == CAUSE_STORE_PAGE_FAULT) {
        handle_page_fault(tf, (uint32_t)cause);
    } else {
#if DBG_PRINT_EN
        printk("[TRAP] unhandled cause=%s (%s) raw=0x%x pc=0x%x\r\n", trap_cause_name(cause), trap_cause_str(cause), cause, tf->sepc);
#endif
        trap_disable();
        for (;;) {
            wfi();
        }
    }
}

uint64_t trap_get_cause(void) {
    return csr_read(CSR_SCAUSE);
}

uint64_t trap_get_pc(struct trap_frame *tf) {
    return tf->sepc;
}

void trap_enable(void) {
    uintptr_t status = csr_read(CSR_SSTATUS);
    csr_write(CSR_SSTATUS, status | SSTATUS_SIE);
}

void trap_disable(void) {
    uintptr_t status = csr_read(CSR_SSTATUS);
    csr_write(CSR_SSTATUS, status & ~SSTATUS_SIE);
}

const char *trap_cause_name(uint64_t cause) {
    switch (cause) {
    case CAUSE_MISALIGNED_FETCH:        return "CAUSE_MISALIGNED_FETCH";
    case CAUSE_FETCH_ACCESS:            return "CAUSE_FETCH_ACCESS";
    case CAUSE_ILLEGAL_INST:            return "CAUSE_ILLEGAL_INST";
    case CAUSE_BREAKPOINT:              return "CAUSE_BREAKPOINT";
    case CAUSE_MISALIGNED_LOAD:         return "CAUSE_MISALIGNED_LOAD";
    case CAUSE_LOAD_ACCESS:             return "CAUSE_LOAD_ACCESS";
    case CAUSE_MISALIGNED_STORE:        return "CAUSE_MISALIGNED_STORE";
    case CAUSE_STORE_ACCESS:            return "CAUSE_STORE_ACCESS";
    case CAUSE_ECALL_U:                 return "CAUSE_ECALL_U";
    case CAUSE_ECALL_S:                 return "CAUSE_ECALL_S";
    case CAUSE_ECALL_M:                 return "CAUSE_ECALL_M";
    case CAUSE_FETCH_PAGE_FAULT:        return "CAUSE_FETCH_PAGE_FAULT";
    case CAUSE_LOAD_PAGE_FAULT:         return "CAUSE_LOAD_PAGE_FAULT";
    case CAUSE_STORE_PAGE_FAULT:        return "CAUSE_STORE_PAGE_FAULT";
    case CAUSE_DOUBLE_TRAP:             return "CAUSE_DOUBLE_TRAP";
    case CAUSE_SOFTWARE_CHECK:          return "CAUSE_SOFTWARE_CHECK";
    case CAUSE_HARDWARE_ERROR:          return "CAUSE_HARDWARE_ERROR";
    case CAUSE_FETCH_GUEST_PAGE_FAULT:  return "CAUSE_FETCH_GUEST_PAGE_FAULT";
    case CAUSE_LOAD_GUEST_PAGE_FAULT:   return "CAUSE_LOAD_GUEST_PAGE_FAULT";
    case CAUSE_VIRTUAL_INSTRUCTION:     return "CAUSE_VIRTUAL_INSTRUCTION";
    case CAUSE_STORE_GUEST_PAGE_FAULT:  return "CAUSE_STORE_GUEST_PAGE_FAULT";
    case CAUSE_IRQ_S_SOFTWARE:          return "CAUSE_IRQ_S_SOFTWARE";
    case CAUSE_IRQ_VS_SOFTWARE:         return "CAUSE_IRQ_VS_SOFTWARE";
    case CAUSE_IRQ_M_SOFTWARE:          return "CAUSE_IRQ_M_SOFTWARE";
    case CAUSE_IRQ_S_TIMER:             return "CAUSE_IRQ_S_TIMER";
    case CAUSE_IRQ_VS_TIMER:            return "CAUSE_IRQ_VS_TIMER";
    case CAUSE_IRQ_M_TIMER:             return "CAUSE_IRQ_M_TIMER";
    case CAUSE_IRQ_S_EXTERNAL:          return "CAUSE_IRQ_S_EXTERNAL";
    case CAUSE_IRQ_VS_EXTERNAL:         return "CAUSE_IRQ_VS_EXTERNAL";
    case CAUSE_IRQ_M_EXTERNAL:          return "CAUSE_IRQ_M_EXTERNAL";
    case CAUSE_IRQ_S_GUEST_EXTERNAL:    return "CAUSE_IRQ_S_GUEST_EXTERNAL";
    case CAUSE_IRQ_COUNTER_OVERFLOW:    return "CAUSE_IRQ_COUNTER_OVERFLOW";
    default:                            return "CAUSE_UNKNOWN";
    }
}

const char *trap_cause_str(uint64_t cause) {
    switch (cause) {
    case CAUSE_MISALIGNED_FETCH:        return "instruction address misaligned";
    case CAUSE_FETCH_ACCESS:            return "instruction access fault";
    case CAUSE_ILLEGAL_INST:            return "illegal instruction";
    case CAUSE_BREAKPOINT:              return "breakpoint";
    case CAUSE_MISALIGNED_LOAD:         return "load address misaligned";
    case CAUSE_LOAD_ACCESS:             return "load access fault";
    case CAUSE_MISALIGNED_STORE:        return "store address misaligned";
    case CAUSE_STORE_ACCESS:            return "store access fault";
    case CAUSE_ECALL_U:                 return "environment call from U-mode";
    case CAUSE_ECALL_S:                 return "environment call from S-mode";
    case CAUSE_ECALL_M:                 return "environment call from M-mode";
    case CAUSE_FETCH_PAGE_FAULT:        return "instruction page fault";
    case CAUSE_LOAD_PAGE_FAULT:         return "load page fault";
    case CAUSE_STORE_PAGE_FAULT:        return "store page fault";
    case CAUSE_DOUBLE_TRAP:             return "double trap";
    case CAUSE_SOFTWARE_CHECK:          return "software check";
    case CAUSE_HARDWARE_ERROR:          return "hardware error";
    case CAUSE_FETCH_GUEST_PAGE_FAULT:  return "instruction guest page fault";
    case CAUSE_LOAD_GUEST_PAGE_FAULT:   return "load guest page fault";
    case CAUSE_VIRTUAL_INSTRUCTION:     return "virtual instruction";
    case CAUSE_STORE_GUEST_PAGE_FAULT:  return "store guest page fault";
    case CAUSE_IRQ_S_SOFTWARE:          return "supervisor software interrupt";
    case CAUSE_IRQ_VS_SOFTWARE:         return "virtual supervisor software interrupt";
    case CAUSE_IRQ_M_SOFTWARE:          return "machine software interrupt";
    case CAUSE_IRQ_S_TIMER:             return "supervisor timer interrupt";
    case CAUSE_IRQ_VS_TIMER:            return "virtual supervisor timer interrupt";
    case CAUSE_IRQ_M_TIMER:             return "machine timer interrupt";
    case CAUSE_IRQ_S_EXTERNAL:          return "supervisor external interrupt";
    case CAUSE_IRQ_VS_EXTERNAL:         return "virtual supervisor external interrupt";
    case CAUSE_IRQ_M_EXTERNAL:          return "machine external interrupt";
    case CAUSE_IRQ_S_GUEST_EXTERNAL:    return "supervisor guest external interrupt";
    case CAUSE_IRQ_COUNTER_OVERFLOW:    return "counter overflow interrupt";
    default:                            return "unknown trap";
    }
}
