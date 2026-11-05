# Timer formal verification

This environment proves the active timer's reset values, free-running time
counter, MMIO response backpressure, request readiness, and interrupt
threshold. Cover goals exercise comparator programming, reads, response
stalling, and interrupt assertion.

## Run

```bash
cd verification/formal/timer
make
```

Generated results belong only under `build/formal/timer`.

