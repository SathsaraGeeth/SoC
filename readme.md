# DMCTP SoC

DMCTP is a SystemVerilog SoC with a processor core, memory, a systolic-array
accelerator, timer, and UART.

## Architecture

```text
                2D checkerboard grid

       +----------------+     +----------------+
       | Compute        |<--->| Memory region  |
       | cluster        |     |                |
       |                |     | Banked SRAM    |
       | Core 0 + router|     | + page engine  |
       | Core 1 + router|     +----------------+
       +----------------+              ^
               ^                       |
               |                       |
       +----------------+     +----------------+
       | Memory region  |<--->| Compute        |
       |                |     | cluster        |
       | Banked SRAM    |     |                |
       | + page engine  |     | Cores + routers|
       +----------------+     +----------------+

       Each router can communicate north, east, south and west.
       Compute and memory cells alternate across the grid.
```

```text
                     One compute/memory region

   +-----------------------+       +--------------------------+
   | Compute cluster       |       | Memory region            |
   |                       |       |                          |
   | +------+   +------+   | I/D   | Address translation      |
   | |Core 0|   |Core 1|   |<----->| and bank arbitration     |
   | |ALU   |   |ALU   |   |       |            |             |
   | |FPU   |   |FPU   |   |       |     Per-bank queues      |
   | +--+---+   +--+---+   |       |            |             |
   |    | Router   | Router|       |   Interleaved SRAM banks |
   +----+----------+-------+       +------------+-------------+
        |          |                            |
        +----------+---- MMIO                    | Page engine
                   |                             |
          +--------+---------+             +-----v------+
          | Timer | UART     |             | External   |
          | Optional         |             | AXI memory |
          | systolic array   |             +------------+
          +------------------+
```

## Project tree

```text
dmctp/
├── rtl/
│   ├── soc/           SoC and router
│   ├── core/          Processor core, ALU and FPU
│   ├── memory/        SRAM and memory controller
│   ├── sys_arr/       Systolic-array accelerator
│   ├── timer/         Timer and watchdog
│   └── uart/          UART
├── kernel/            Kernel and device drivers
├── user/              Userspace programs and libraries
├── verification/
│   ├── simulator/     SoC simulator
│   └── uvm/
│       ├── isa/       ISA verification
│       └── uart/      UART verification
└── regressions/truth/ Simulator configuration
```
