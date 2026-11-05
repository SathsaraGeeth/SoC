/*
 * Comments:
 * 1. Currently when trapped prints the cause and epc and then park ourself.
 */


#include <stdint.h>
#include <regs.h>
#include <console_early.h>

void trap_init(void) {
    extern void _trap_entry(void);
    uint32_t tid = csr_read(CSR_THREAD_ID);
    /* BL1 owns mtvec for the lifetime of the machine-mode firmware. */
    console_early_puts("[BL2] trap vectors ok\r\n");
}

void trap_handler(uint32_t *sp) {
    (void)sp;
    uint32_t cause = csr_read(CSR_MCAUSE);
    uint32_t epc   = csr_read(CSR_MEPC);
    uint32_t tid   = csr_read(CSR_THREAD_ID);

    console_early_puts("[TRAP] cause=");
    console_early_puthex32(cause);
    console_early_puts(" epc=");
    console_early_puthex32(epc);
    console_early_puts("\r\n");

    while (1) {
        __asm__ volatile ("wfi");
    }
}
