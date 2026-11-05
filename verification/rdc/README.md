# RDC development checks

This directory inventories asynchronous reset usage and supplies reusable reset
assertion modules. It is a development check, not RDC signoff.

Run:

```sh
make -C verification/rdc TARGET=soc
make -C verification/rdc uart
```

Reports are written to `build/rdc/<target>/`. The current design exposes one
active-low reset (`i_rst_n`). The UART domain receives asynchronous assertion
and synchronous release through `uart_reset_sync`; the report inventories that
instance. Direct reset use in the system domain remains a review item, not an
automatic failure. Add reset relations and isolation rules when further
independently reset domains are introduced.
`yosys_reset_sync.rpt` records elaboration and structural statistics for the
reset-release primitive.
