# Register-file UVM

This environment initializes every nonzero register in every hardware thread,
then checks randomized three-port reads, writes, x0 hardwiring, and thread
isolation against an independent reference array.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/regfile -B build/uvm/regfile
cmake --build build/uvm/regfile --target dsim_run
```

Generated files belong only under `build/uvm/regfile`.

