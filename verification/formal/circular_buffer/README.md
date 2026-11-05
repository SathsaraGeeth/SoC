# Circular buffer formal verification

This environment proves circular-buffer safety, occupancy accounting, and FIFO
ordering properties and exercises important reachable states with SymbiYosys.

## Layout

- `properties/` separates reset, status, protocol, and data-ordering properties.
- `env/circular_buffer_env.sv` instantiates the DUT and assembles the property files.
- `env/circular_buffer_assumptions.sv` constrains initial reset.
- `env/circular_buffer_coverpoints.sv` contains reachability goals.
- `prove/full.sby` runs the complete bounded/inductive safety proof.
- `cover/full.sby` generates reachability traces.
- `scripts/` provides individual, combined, and cleanup commands.
- `../../../build/formal/circular_buffer/prove/` and
  `../../../build/formal/circular_buffer/cover/` contain generated SymbiYosys results.

Generated files belong only under the repository-root
`build/formal/circular_buffer/`; source and job definitions remain outside it.

## Run

```bash
cd verification/formal/circular_buffer
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
