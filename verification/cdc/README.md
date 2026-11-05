# CDC development checks

This directory provides structural discovery, reusable CDC primitives, and
protocol assertion modules for DMCTP. It is a development aid, not CDC signoff.
Use a commercial CDC tool with reviewed constraints and waivers for signoff.

The current distributed SoC has one functional clock (`i_clk`).  Its reset is
asynchronously asserted at the boundary and synchronously released by separate
`reset_sync` instances for fabric/control (`rst_fabric_n`), each cluster
(`rst_cluster_n[]`), each memory region (`rst_mem_n[]`), peripherals
(`rst_periph_n`), and the accelerator/system-core (`rst_accel_n`).  The reset-
domain declarations are in `common/resets.tcl`.  External
asynchronous inputs, such as UART RX, use a recognized single-bit synchronizer.

Run:

```sh
make -C verification/cdc TARGET=soc
make -C verification/cdc uart
```

Reports are written to `build/cdc/<target>/`. `domains.rpt` inventories
`always_ff` clock/reset expressions and `domains.json` is machine-readable.
`yosys_primitives.rpt` checks that the reusable primitive hierarchy elaborates.
The report inventories asynchronous reset expressions and reset synchronizer
instances, so it is also the project's RDC development check.  It is not a
replacement for elaborated-netlist RDC signoff.
The scanner is intentionally conservative: it does not replace elaborated
netlist crossing analysis.

Use `cdc_bit_sync` only for independent single-bit levels, `cdc_pulse_sync` for
rate-constrained pulse events, `cdc_handshake` for coherent held data,
`cdc_gray_sync` for Gray-coded state, and `async_fifo` for streams. Each
destination clock domain should use a separately instantiated `reset_sync` if
reset deassertion is asynchronous to that clock.
