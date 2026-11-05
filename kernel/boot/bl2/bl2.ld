#include <soc.h>

ENTRY(_bl2_reset)

MEMORY {
    RAM (rwx) : ORIGIN = BL2_BASE, LENGTH = BL2_SIZE
}

SECTIONS {
    .text     : ALIGN(ARCH_WORD_SIZE) { *(.bl2_entry) *(.text .text.*)                                                            } > RAM
    .rodata   : ALIGN(ARCH_WORD_SIZE) { *(.rodata .rodata.*)                                                                      } > RAM
    .data     : ALIGN(ARCH_WORD_SIZE) { *(.data .data.*)                                                                          } > RAM
    .bss      : ALIGN(ARCH_WORD_SIZE) { _bl2_bss_start = .; *(.bss .bss.*) *(COMMON) . = ALIGN(ARCH_WORD_SIZE); _bl2_bss_end = .; } > RAM
    _bl2_stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
