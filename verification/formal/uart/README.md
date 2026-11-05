# UART formal verification

This environment proves UART safety properties and exercises important
reachable protocol states with SymbiYosys.

## Layout

- `properties/` separates reset, FIFO, status, TX, RX, protocol, and interrupt
  properties.
- `env/uart_env.sv` instantiates the DUT and assembles the property files.
- `env/uart_assumptions.sv` constrains reset and baud configuration.
- `env/uart_coverpoints.sv` contains reachability goals.
- `prove/full.sby` runs the complete bounded/inductive safety proof.
- `cover/full.sby` generates reachability traces.
- `scripts/` provides individual, combined, and cleanup commands.
- `../../../build/formal/uart/prove/` and `../../../build/formal/uart/cover/`
  contain generated SymbiYosys results.

Generated files belong only under the repository-root `build/formal/uart/`;
source and job definitions remain
outside it.

## Run

```bash
cd verification/formal/uart
make
```

Individual jobs:

```bash
make prove
make cover
```

The equivalent script entry points are:

```bash
./scripts/run_all.sh
./scripts/run_prove.sh
./scripts/run_cover.sh
```

Clean generated results with `make clean`.

If `~/tools/oss-cad-suite/bin/sby` exists, the Makefile adds that toolchain to
`PATH`. Override it with `OSS_CAD_SUITE=/path/to/oss-cad-suite` or
`SBY=/path/to/sby`.
