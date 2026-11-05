# Circular-buffer UVM

This environment uses a queue reference model to check ordering, simultaneous
enqueue/dequeue, clear, full/empty flags, ready signaling, and level accounting.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/circular_buffer -B build/uvm/circular_buffer
cmake --build build/uvm/circular_buffer --target dsim_run
```

Generated files belong only under `build/uvm/circular_buffer`.

