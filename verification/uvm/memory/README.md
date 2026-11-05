# Memory UVM verification

This suite verifies translated multi-port reads and writes, byte data integrity, response routing, and thread metadata.

```sh
cmake -S verification/uvm/memory -B build/uvm/memory
cmake --build build/uvm/memory --target dsim_run
```

