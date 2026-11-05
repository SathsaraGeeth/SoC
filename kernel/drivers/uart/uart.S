	.file	"uart.c"
	.option	push
	.option	arch, +zalrsc
	.text
	.globl	uart_init                       # -- Begin function uart_init
	.p2align	2
	.type	uart_init,@function
uart_init:                              # @uart_init
# %bb.0:
	lui	r10, 65536
	addi.i32	r11, r0, 1
	store.32	r11, 8(r10)
	jump.abs	r0, 0(r1)
.Lfunc_end0:
	.size	uart_init, .Lfunc_end0-uart_init
                                        # -- End function
	.option	pop
	.option	push
	.option	arch, +zalrsc
	.globl	uart_putc                       # -- Begin function uart_putc
	.p2align	2
	.type	uart_putc,@function
uart_putc:                              # @uart_putc
# %bb.0:
	lui	r11, 65536
.LBB1_1:                                # =>This Inner Loop Header: Depth=1
	load.i32	r12, 0(r11)
	bc.lt	r12, r0, .LBB1_1
# %bb.2:
	lui	r11, 65536
	store.32	r10, 0(r11)
	jump.abs	r0, 0(r1)
.Lfunc_end1:
	.size	uart_putc, .Lfunc_end1-uart_putc
                                        # -- End function
	.option	pop
	.option	push
	.option	arch, +zalrsc
	.globl	uart_puts                       # -- Begin function uart_puts
	.p2align	2
	.type	uart_puts,@function
uart_puts:                              # @uart_puts
# %bb.0:
	addi.i32	r11, r0, 10
	lui	r12, 65536
	addi.i32	r13, r0, 13
	load.u8	r14, 0(r10)
	bc.eq	r14, r11, .LBB2_2
.LBB2_1:
	bc.ne	r14, r0, .LBB2_4
	jump.rel.dir	r0, .LBB2_7
.LBB2_2:                                # =>This Inner Loop Header: Depth=1
	load.i32	r14, 0(r12)
	bc.lt	r14, r0, .LBB2_2
# %bb.3:
	store.32	r13, 0(r12)
.LBB2_4:
	load.u8	r14, 0(r10)
.LBB2_5:                                # =>This Inner Loop Header: Depth=1
	load.i32	r15, 0(r12)
	bc.lt	r15, r0, .LBB2_5
# %bb.6:
	addi.i32	r10, r10, 1
	store.32	r14, 0(r12)
	load.u8	r14, 0(r10)
	bc.ne	r14, r11, .LBB2_1
	jump.rel.dir	r0, .LBB2_2
.LBB2_7:
	jump.abs	r0, 0(r1)
.Lfunc_end2:
	.size	uart_puts, .Lfunc_end2-uart_puts
                                        # -- End function
	.option	pop
	.ident	"clang version 23.0.0git (https://github.com/llvm/llvm-project.git 6619aa70071db7d3a589fe50474e19c58dbca8f9)"
	.section	".note.GNU-stack","",@progbits
