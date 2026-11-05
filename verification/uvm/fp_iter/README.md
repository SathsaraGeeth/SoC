# FP iteration-controller UVM environment

This self-checking environment verifies normal pipe-result bypass on both
lanes and the architecturally exact divide-by-zero and negative-square-root
special cases.  It also checks ownership, ready/valid behavior, result routing,
and thread-tag preservation.

```sh
cmake -S verification/uvm/fp_iter -B build/uvm/fp_iter \
  -DDSIM_HOME=/home/geeth/AltairDSim/2026
cmake --build build/uvm/fp_iter --target dsim_run
```
