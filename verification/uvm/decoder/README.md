# Decoder UVM

This environment generates randomized register fields and immediates across
integer ALU, load/store, branch, jump, upper-immediate, and CSR instruction
classes. The scoreboard independently checks routing, hazards, write enables,
operation selection, and decoded immediates.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/decoder -B build/uvm/decoder
cmake --build build/uvm/decoder --target dsim_run
```

Generated files belong only under `build/uvm/decoder`.

