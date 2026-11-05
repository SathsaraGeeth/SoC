# Timer UVM

This environment checks the active timer MMIO implementation, including the
free-running counter, split comparator reads and writes, byte strobes,
response backpressure, and interrupt threshold.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/timer -B build/uvm/timer
cmake --build build/uvm/timer --target dsim_run
```

Generated files belong only under `build/uvm/timer`.

