# Reset synchronizer UVM

This environment checks asynchronous reset assertion and two-stage synchronous
release, including non-clock-aligned reset pulses.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/reset_sync -B build/uvm/reset_sync
cmake --build build/uvm/reset_sync --target dsim_run
```

Generated files belong only under `build/uvm/reset_sync`.

