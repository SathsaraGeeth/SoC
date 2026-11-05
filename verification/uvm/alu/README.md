# ALU UVM

This environment drives both ALU lanes with randomized arithmetic, comparison,
logic, shift, multiply, branch, jump, word-operation, thread-tag, and
backpressure scenarios. The scoreboard computes results independently.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/alu -B build/uvm/alu
cmake --build build/uvm/alu --target dsim_run
```

Generated RTL and simulation files belong only under `build/uvm/alu`.

