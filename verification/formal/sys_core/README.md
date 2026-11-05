# System core formal verification

This environment proves the MMIO and command-ownership control plane of the
active `sys_core`: reset, response backpressure, command-word assembly,
delegation, release, owner-only request gating, and busy/interrupt tracking.
The address generators, FIFOs, and MMACU use interface-contract stubs because
they are proved and simulated separately in their focused environments.

## Run

```bash
cd verification/formal/sys_core
make
```

