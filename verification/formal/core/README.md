# Core formal verification

This environment verifies the active top-level `core` boundary using the real
decoder, threaded register file, ALU, FPU, CSR, and queue RTL. It checks reset
state, request metadata and alignment, accepted-request bookkeeping, response
acceptance, and ready/valid payload stability. The existing `uvm/isa` suite is
the corresponding full instruction-level UVM environment.

The generated source copies only resolve tool portability issues; production
RTL is not rewritten.

The proof uses the full two-lane implementation. Slang/Yosys reports
synthesis-only combinational SCCs after lowering the core's unpacked state
arrays. The cover job exposes and cuts only those lowered SCC outputs before
SMT generation; it does not rewrite the source RTL. The safety proof retains
the full implementation and is not cut.

The proof currently fails `properties/core_instruction_protocol.sv` P4. A
wake interrupt can change the chosen thread while an instruction request is
backpressured, which changes the valid request payload before it is accepted.
This is retained as a regression failure rather than weakened or assumed away.
ABC finds the failure in frame 3. Counterexample conversion is disabled because
the installed `yosys-witness` cannot convert this design's unpacked-array map;
the failing property and frame are recorded in the SBY log.

## Run

```bash
cd verification/formal/core
make
```
