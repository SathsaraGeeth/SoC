# Include common packages and shared RTL
-f verification/lint/filelists/common.f
rtl/common/reset/reset_sync.sv

# Core
rtl/core/regfile.sv
rtl/core/alu.sv
rtl/core/decoder.sv
rtl/core/csr.sv
rtl/core/fpu/fpu_iter.sv
rtl/core/fpu/fpu.sv
rtl/core/fpu.sv
rtl/core/core.sv

# Memory subsystem
rtl/memory/page_engine.sv
rtl/memory/sram_bank.sv
rtl/memory/memory.sv

# SoC / NOC
rtl/soc/router.sv
rtl/soc/soc.sv

# Sys Array
rtl/sys_arr/mac20i.sv
rtl/sys_arr/mac20i_v2.sv
rtl/sys_arr/mac_fp8_fp8_fp8_61.sv
rtl/sys_arr/mac_fp8_fp8_fp8_61_v2.sv
rtl/sys_arr/mmacu_core.sv
rtl/sys_arr/mmacu_core_v2.sv
rtl/sys_arr/sys_address_generator.sv
rtl/sys_arr/sys_core.sv
rtl/sys_arr/mmacu.sv

# Timer
rtl/timer/timer.sv

# UART
rtl/uart/uart_if.sv
rtl/uart/uart_mmio.sv
rtl/uart/uart.sv
