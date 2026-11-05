#include <soc.h>

ENTRY(_kernel_start)

MEMORY {
    RAM (rwx) : ORIGIN = KERNEL_BASE, LENGTH = KERNEL_SIZE
}
SECTIONS {
    .text   : { *(.kernel_entry) *(.text .text.*)                                                                                     } > RAM
    .rodata : ALIGN(ARCH_WORD_SIZE) { *(.rodata .rodata.*)                                                                            } > RAM
    .data   : ALIGN(ARCH_WORD_SIZE) { *(.data .data.*)                                                                                } > RAM
    .bss    : ALIGN(ARCH_WORD_SIZE) { _kernel_bss_start = .; *(.bss .bss.*) *(COMMON) . = ALIGN(ARCH_WORD_SIZE); _kernel_bss_end = .; } > RAM
    _kernel_stack_top = ORIGIN(RAM) + LENGTH(RAM);
 }
