# CSR UVM

This environment checks per-thread CSR storage, architectural status views,
thread IDs, timer-pending state, delegation outputs, traps, and MRET/SRET
privilege transitions against an independent per-thread model.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/csr -B build/uvm/csr
cmake --build build/uvm/csr --target dsim_run
```

Generated RTL and simulation files belong only under `build/uvm/csr`.

