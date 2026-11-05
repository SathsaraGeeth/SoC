# MMACU core v2 formal verification

This environment proves reset, native-mode ready/valid behavior, global output
stalling, flush entry/progress/exit, and result stability. Formal uses a
two-by-two INT8 array to bound the replicated state; UVM exercises the complete
eight-by-eight production geometry and checks arithmetic row data.

## Run

```bash
cd verification/formal/mmacu_core_v2
make
```

