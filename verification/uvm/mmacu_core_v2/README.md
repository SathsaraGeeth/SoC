# MMACU core v2 UVM

This environment verifies the active systolic-array core in native INT8 mode.
It checks full 8-by-8 matrix products, input handshakes, result row ordering,
signed arithmetic, end flushing, and output backpressure. Dense-mode reuse is
covered at the integrating `sys_core` boundary.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/mmacu_core_v2 -B build/uvm/mmacu_core_v2
cmake --build build/uvm/mmacu_core_v2 --target dsim_run
```

