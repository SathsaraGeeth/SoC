# Systolic helper UVM verification

This suite verifies every helper in `rtl/sys_arr/common.sv`: register, mux, fixed and variable delay pipes, multiplier, adder, and counter.

```sh
cmake -S verification/uvm/sys_common -B build/uvm/sys_common
cmake --build build/uvm/sys_common --target dsim_run
```

