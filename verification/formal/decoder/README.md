# Decoder formal verification

This environment proves structural decoder invariants and functional-unit
routing for every symbolic instruction word. It uses the same build-only
qualified RTL copy as the existing core ISA UVM flow because the source
currently has overlapping wildcard package imports.

## Run

```bash
cd verification/formal/decoder
make
```

Generated RTL and proof results belong only under `build/formal/decoder`.

