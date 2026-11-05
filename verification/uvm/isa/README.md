# Core ISA UVM

## TODO
1. Extend to the previledge specs
2. Extend to floating point instructions
   after floating point support is added

## Scope
1. This Excercise the core's complience with the isa.yaml
   under unpreviledge specs.
2. It does not Intentionally consider
    - previledge specs
    - memory system related
        i.   TLB / virtual memory
        ii.  MMIO
        iii. Routers
    - phehiperals
    - accelrators
    - storage or page engine(dma)
3. Testbenches asserts the equivalance of the architectural
   commits against the golden model.
4. So this enviorement's focus is about the architectural
   equivalence, rather than the microarchicture.
5. So the testbench is carried out stricly in M-mode.

## Run

```sh
cd verification/uvm/isa
./scripts/run.sh
```

use seed `1` by default
```sh
ISA_RANDOM_SEED=42 ./scripts/run.sh
```
