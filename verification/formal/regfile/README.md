# Register-file formal verification

This environment proves register-file safety properties and exercises
important write/read and thread-isolation scenarios with SymbiYosys.

## Layout

- `properties/regfile_x0.sv` contains x0 hardwiring properties.
- `properties/regfile_reads.sv` contains multi-port read-consistency
  properties.
- `env/regfile_env.sv` instantiates the DUT and assembles the property files.
- `env/regfile_coverpoints.sv` contains reachability goals.
- `prove/full.sby` runs the complete safety proof.
- `cover/full.sby` generates reachability traces.
- `scripts/` provides individual, combined, and cleanup commands.
- `../../../build/formal/regfile/prove/` and `../../../build/formal/regfile/cover/`
  contain generated SymbiYosys results.

Generated files belong only under the repository-root `build/formal/regfile/`;
source and job definitions remain
outside it.

## Run

```bash
cd verification/formal/regfile
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
