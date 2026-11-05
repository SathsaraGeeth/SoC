# CSR formal verification

This environment proves reset privilege, architectural read-only CSR views,
delegation outputs, timer-pending logic, and trap/return privilege transitions
for every hardware thread.

## Run

```bash
cd verification/formal/csr
make
```

Generated RTL and proof results belong only under `build/formal/csr`.

