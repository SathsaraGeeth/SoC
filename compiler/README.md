# DMCTP LLVM toolchain

This directory contains the LLVM/Clang toolchain with the 
DMCTP backend and some tests.

## Build the toolchain

From the repository root:

```bash
cmake -S compiler/llvm-project/llvm \
  -B compiler/llvm-project/build \
  -G Ninja \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD="RISCV" \
  -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="DMCTP" \
  -DCMAKE_BUILD_TYPE=Release

cmake --build compiler/llvm-project/build --parallel
```

The tools are installed in `compiler/llvm-project/build/bin`.


To rebuild an existing configured tree:

```bash
cmake --build compiler/llvm-project/build --parallel
```

## Compile and link a DMCTP program

The DMCTP backend uses the `dmctp64` architecture name. A minimal freestanding
flow is:

```bash
compiler/llvm-project/build/bin/clang \
  -target dmctp64 -ffreestanding -nostdlib \
  -S -emit-llvm input.c -o input.ll

compiler/llvm-project/build/bin/llc \
  -march=dmctp64 input.ll -o input.s

compiler/llvm-project/build/bin/llvm-mc \
  -arch=dmctp64 -filetype=obj input.s -o input.o

compiler/llvm-project/build/bin/ld.lld \
  -T path/to/link.ld input.o -o input.elf
```

For complete programs, prefer the repository build:

```bash
make -C user dmctp
```

That build selects the DMCTP Clang and linker, runtime objects, linker script,
and application libraries consistently.

## Test the backend

The compiler smoke tests and examples are in `compiler/test`:

```bash
make -C compiler/test
```

See `compiler/test/README.txt` for individual LLVM IR, assembly, and cocotb
commands.

## Configuration source

SoC configuration is owned by `regressions/truth/soc.yaml`. Synchronize
generated RTL, kernel, user, and simulator settings after changing it:

```bash
./regressions/truth/sync.sh
```
