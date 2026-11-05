# Reset synchronizer formal verification

This environment proves asynchronous assertion, ordered synchronizer shifting,
the configured release latency, and monotonic reset release for `reset_sync`.
The proof uses three stages so the parameterized shift behavior is exercised
beyond the minimum legal configuration.

## Layout

- `properties/` separates reset and release-protocol properties.
- `env/reset_sync_env.sv` instantiates the DUT and assembles the property files.
- `env/reset_sync_assumptions.sv` constrains initial reset.
- `env/reset_sync_coverpoints.sv` contains reset/release reachability goals.
- `prove/full.sby` runs the safety proof.
- `cover/full.sby` generates reachability traces.
- `scripts/` provides individual, combined, and cleanup commands.

Generated files belong under `build/formal/reset_sync/`.

## Run

```bash
cd verification/formal/reset_sync
make
```
