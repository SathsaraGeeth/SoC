# Memory formal verification

This environment proves request capture, reset state, page-message readiness,
page-transfer handshakes, completion tracking, and response arbitration. To
keep the SRAM/TLB state finite enough for exhaustive exploration, formal uses
the production RTL with a verification-only one-port, two-bank, four-page
`memory_pkg`. The UVM memory suite exercises the full production geometry.
The proof model also opens the SRAM clock gates, a standard formal abstraction;
all memory control and gating decisions remain otherwise unchanged.

## Run

```bash
cd verification/formal/memory
make
```

Generated results belong only under `build/formal/memory`.
