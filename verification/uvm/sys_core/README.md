# System core UVM

This environment verifies the active system-array control plane: 256-bit
command assembly, delegation and release ownership, host gating, status reads,
MMIO response backpressure, and idle memory-port behavior. Arithmetic,
address-generation, and MAC datapaths have their own focused suites.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/sys_core -B build/uvm/sys_core
cmake --build build/uvm/sys_core --target dsim_run
```

