# UART MMIO formal verification

This environment proves reset, register-write privilege and byte masks,
request capture, response backpressure, and response tags for the UART MMIO
wrapper. The serial engine is replaced by a small interface-contract stub;
the serial engine itself is covered by `verification/formal/uart`.

## Run

```bash
cd verification/formal/uart_mmio
make
```

Generated results belong only under `build/formal/uart_mmio`.

