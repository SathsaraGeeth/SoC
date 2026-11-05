OUTPUT_ARCH( "riscv" )
ENTRY( _start )

SECTIONS
{
  . = 0x00000000;

  .text : {
    *(.text)
  }

  .data : {
    . = ALIGN(8);
    *(.data)
    *(.rodata)
  }

  .bss : {
    . = ALIGN(8);
    *(.bss)
  }
}
