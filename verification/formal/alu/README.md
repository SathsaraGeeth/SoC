# ALU formal verification

This environment proves one branch-capable ALU lane. It checks reset and
ready/valid backpressure, thread and branch metadata, and arithmetic, logic,
shift, comparison, and jump results using symbolic operands.

## Run

```bash
cd verification/formal/alu
make
```

Generated RTL and proof results belong only under `build/formal/alu`.

