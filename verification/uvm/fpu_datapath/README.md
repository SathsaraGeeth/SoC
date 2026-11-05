# FPU datapath UVM environment

This self-checking UVM environment verifies both `fpu_datapath` lanes with
directed FP32 add, subtract, multiply, and fused multiply-add operations.  The
scoreboard checks the numerical result, lane routing, and full-width thread tag.

Build and run with:

```sh
cmake -S verification/uvm/fpu_datapath -B build/uvm/fpu_datapath \
  -DDSIM_HOME=/home/geeth/AltairDSim/2026
cmake --build build/uvm/fpu_datapath --target dsim_run
```
