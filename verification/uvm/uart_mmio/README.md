# UART MMIO UVM

This environment checks the active UART register wrapper independently from
the serial-block environment. It covers privileged and unprivileged accesses,
byte strobes, register reset values, illegal offsets, response backpressure,
thread tags, and TXDATA requests.

## Run

```bash
cd /mnt/fileserver/prj/dmctp
cmake -S verification/uvm/uart_mmio -B build/uvm/uart_mmio
cmake --build build/uvm/uart_mmio --target dsim_run
```

Generated files belong only under `build/uvm/uart_mmio`.

