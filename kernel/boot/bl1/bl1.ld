#include <soc.h>

ENTRY(_bl1_start)

MEMORY {
    ROM (rx)  : ORIGIN = ROM_BASE, LENGTH = ROM_SIZE
    RAM (rwx) : ORIGIN = BL1_BASE, LENGTH = BL1_SIZE
}

SECTIONS {
    .text     : { KEEP(*(.boot_rom)) *(.text)           } > ROM
    .rodata   : { *(.rodata)                            } > ROM
    .data     : { *(.data)                              } > RAM
    .bss      : { _bss_start = .; *(.bss) _bss_end = .; } > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);    /* stack grows down from the top of RAM */
}
