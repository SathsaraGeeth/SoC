# SRAM bank UVM verification

This suite verifies byte writes, reads, response backpressure, metadata, and LR/SC reservation behavior.

```sh
cmake -S verification/uvm/sram_bank -B build/uvm/sram_bank
cmake --build build/uvm/sram_bank --target dsim_run
```

