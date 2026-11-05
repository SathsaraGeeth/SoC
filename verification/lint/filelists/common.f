# Common packages and shared RTL
+incdir+rtl

# Packages (must come before modules that import them)
rtl/isa/isa_pkg.sv
rtl/core/core_pkg.sv
rtl/core/fpu/fpu_pkg.sv
rtl/core/fpu/fpu_functions_pkg.sv
rtl/soc/topology_pkg.sv
rtl/memory/memory_pkg.sv
rtl/soc/soc_pkg.sv
rtl/sys_arr/sys_cnfg_pkg.sv
rtl/sys_arr/mac_fp8_fp8_fp8_61_cnfg_pkg.sv

# Common modules
rtl/common/fifo/circular_buffer.sv
rtl/sys_arr/common.sv
