# Router formal verification

This environment proves the active router's direction selection, MMIO
separation, request payload preservation, page-message priority, reset state,
and response stability under backpressure. The real circular reorder buffers
and real router RTL are used. The generated source is a tool-portability copy
that only qualifies ambiguous package names and moves a forward declaration;
the production RTL is unchanged.

## Run

```bash
cd verification/formal/router
make
```
