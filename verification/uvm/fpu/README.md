# Core-facing FPU UVM

This environment checks the core-facing FPU adapter's simple IEEE-754
operations, request serialization, result backpressure, and thread tags.
Arithmetic-pipeline and iterative operations have their own unit suites.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/fpu -B build/uvm/fpu
cmake --build build/uvm/fpu --target dsim_run
```

Generated RTL and simulation files belong only under `build/uvm/fpu`.

