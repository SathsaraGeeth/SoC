# DMCTP compiler tests

Coverage:

- ISA derived assembly mnemonic and encoding validation
- deterministic random programs
- `O0`, `O1`, `O2`, `O3`, `Os`, and `Oz`
- integer arithmetic, comparisons, branches, calls, and constants
- signed immediate boundaries and forward/backward control flow
- LR/SC atomics
- byte, halfword, word, and doubleword load/store stress
- CSR, fence, trap-return, wait, and environment-call system instructions
- deterministic object generation and rejected invalid assembly

Run the complete suite with:

```bash
make -C compiler/test test
```

CI uses `smoke` on every commit and `extended` for presubmit and slower tiers.
Generated files stay under `compiler/test/build/`.

Set `DMCTP_LLVM_BIN` when the compiler tools are installed outside the
repository build tree. Jenkins uses this for its sparse disposable workspaces.
