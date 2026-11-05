# Router UVM verification

This environment verifies the active `router` with the same transaction,
agent, scoreboard, coverage, and test organization as the other UVM suites.
It checks instruction and data routing in all four directions, user-mode local
routing, MMIO selection, ordered memory/MMIO responses, page-message routing
and priority, payload preservation, and output stability under backpressure.

## Run

```bash
cmake -S verification/uvm/router -B build/uvm/router \
  -DDSIM_HOME=/home/geeth/AltairDSim/2026
cmake --build build/uvm/router --target dsim_run
```
