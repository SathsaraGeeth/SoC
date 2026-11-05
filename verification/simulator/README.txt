DMCTP simulator build and run
=============================

The simulator consumes three kernel images from ../kernel/build:

  - boot_rom.elf:   BL1, converted into SRAM bank hex files
  - bl2.elf:        BL2, copied into simulated block storage
  - bl2A.elf:       BL2A, copied into simulated block storage
  - kernel.elf:     kernel, copied into simulated block storage

The simulator run script rebuilds both the kernel and userspace with the native
experimental DMCTP backend after synchronizing the SoC configuration. This
prevents stable-backend objects or objects built for an older topology from
being reused. It also regenerates the filesystem image.


Use the old/stable compiler
===========================

The old compiler is the normal build/bin toolchain:

  OLD_LLVM=/mnt/fileserver/prj/dmctp/compiler/llvm-project/build/bin

Build the kernel with it:

  cd /mnt/fileserver/prj/dmctp/kernel
  make clean
  make -j"$(nproc)" LLVM_BIN="$OLD_LLVM"

For <kernel_trap> diagnostics:

  cd /mnt/fileserver/prj/dmctp/kernel
  make clean
  make -j"$(nproc)" LLVM_BIN="$OLD_LLVM" KERNEL_TRAP_DBG=1

The kernel Makefile supplies the target triple:

  dmctpArch-dmctpVendor-dmctpOS

The old compiler tools used by the kernel are clang, llvm-mc, ld.lld, and
llvm-objcopy from build/bin.

This is the currently supported complete simulator toolchain. Use this flow
when you need a runnable kernel and userspace filesystem image.


Use the experimental compiler
=============================

The experimental compiler is:

  EXP_LLVM=/mnt/fileserver/prj/dmctp/compiler/llvm-project/build-experimental/bin

Build the experimental kernel with:

  cd /mnt/fileserver/prj/dmctp/kernel
  make clean
  make -j"$(nproc)" LLVM_BIN="$EXP_LLVM"

The experimental kernel uses the native DMCTP triple and DMCTP assembly
syntax:

  dmctpArch-dmctpVendor-dmctpOS

The experimental userspace C frontend can compile C files with:

  "$EXP_LLVM/clang" --target=dmctpArch-dmctpVendor-dmctpOS \
    -ffreestanding -O2 -nostdlib \
    -Iuser/include -Iuser/include/libc \
    -c user/src/init/main.c -o /tmp/init-exp.o

The userspace Makefile has a native experimental mode. It selects the DMCTP
triple, uses user/src/lib/runtime/crt0_dmctp.S, assembles that startup file
with llvm-mc, and maps syscall argument registers to DMCTP r10-r16:

  cd /mnt/fileserver/prj/dmctp/user
  make clean
  make dmctp DMCTP_MODE=experimental

This builds the normal userspace programs with the new compiler and writes
their ELF files to user/bin. The current backend does not yet lower every
operation used by smpd_bench (cttz and 32-bit unsigned remainder), so that
benchmark is excluded from the experimental build until those target
lowerings are implemented. Build the currently supported set explicitly:

  make dmctp DMCTP_MODE=experimental \
    DMCTP_PROGRAMS='arithm_test cat fb_demo free init ls lscpu nano sh \
    test_page_fault test_sys_dense test_sys_fp8 test_timer thread_test utest'

Do not mix the old RISC-V crt0.S with experimental DMCTP objects. The
experimental path uses the DMCTP startup file and syscall ABI together.


Build the user applications with the old compiler
==================================================

The user Makefile already defaults to the old compiler, but the paths can be
made explicit:

  OLD_LLVM=/mnt/fileserver/prj/dmctp/compiler/llvm-project/build/bin
  cd /mnt/fileserver/prj/dmctp/user
  make clean
  make dmctp DMCTP_CC="$OLD_LLVM/clang" DMCTP_LD="$OLD_LLVM/ld.lld"

The user applications use the stable RISC-V-compatible userspace target when
`DMCTP_MODE=stable` is selected:

  --target=riscv64 -march=rv64i_zmmul_zalrsc -mabi=lp64

ELF files are written to user/bin. The simulator run script packages those
ELFs into build/simulator/block_storage/fs.bin.

To build only the user applications without cleaning:

  cd /mnt/fileserver/prj/dmctp/user
  make dmctp


Complete simulator build and run
================================

1. Synchronize generated truth/configuration files:

  cd /mnt/fileserver/prj/dmctp
  ./regressions/truth/sync.sh

2. Build the kernel with the selected compiler.

For the currently supported old/stable simulator image:

  cd /mnt/fileserver/prj/dmctp/kernel
  make clean
  make -j"$(nproc)" LLVM_BIN=/mnt/fileserver/prj/dmctp/compiler/llvm-project/build/bin

For experimental kernel-only work:

  make clean
  make -j"$(nproc)" LLVM_BIN=/mnt/fileserver/prj/dmctp/compiler/llvm-project/build-experimental/bin

3. Build userspace with the old/stable compiler:

  cd /mnt/fileserver/prj/dmctp/user
  make clean
  make dmctp \
    DMCTP_CC=/mnt/fileserver/prj/dmctp/compiler/llvm-project/build/bin/clang \
    DMCTP_LD=/mnt/fileserver/prj/dmctp/compiler/llvm-project/build/bin/ld.lld

4. Build the simulator model and run from a fresh boot:

  cd /mnt/fileserver/prj/dmctp/verification/simulator
  ./run --distributed

For the experimental kernel and experimental userspace image, export the
userspace mode and select the currently supported programs:

  cd /mnt/fileserver/prj/dmctp/verification/simulator
  DMCTP_MODE=experimental \
  DMCTP_PROGRAMS='arithm_test cat fb_demo free init ls lscpu nano sh \
  test_page_fault test_sys_dense test_sys_fp8 test_timer thread_test utest' \
  timeout 120 ./run --distributed

The script automatically:

  - rebuilds the kernel with the experimental DMCTP backend for the
    synchronized SoC configuration;
  - converts boot_rom.elf into build/simulator/boot_rom/bank*.hex;
  - converts BL2, BL2A, and kernel into block-storage binaries;
  - builds the user applications using user/Makefile;
  - creates build/simulator/block_storage/fs.bin;
  - rebuilds the Verilator model;
  - starts hostd and the SoC simulator.

To build the simulator model without starting it:

  cd /mnt/fileserver/prj/dmctp/verification/simulator
  ./run --distributed --build-only

To run an already-built model directly:

  cd /mnt/fileserver/prj/dmctp/build/simulator
  ./tools/hostd ./hostroot ./obj_dir/Vsoc

The number of generated boot-ROM banks must match the RTL configuration. If
the simulator stops at the banner, check NUM_BANKS and rerun the truth sync.


Run user programs
=================

After the simulator reaches the DMCTP shell, run an application by its image
name, for example:

  utest
  ls
  lscpu
  test_timer.elf

For an application that is present as an ELF in the filesystem image, use:

  run /bin/fb_demo.elf

To build and run the native FP32 userspace test with bounded FPU request/result
probes enabled in the RTL model:

  cd /mnt/fileserver/prj/dmctp/verification/simulator
  DMCTP_MODE=experimental DMCTP_PROGRAMS='init sh test_float' \
    FPU_TRACE=1 ./run --distributed

At the shell, enter `test_float`. The test checks the exact FP32 result bits for
addition, subtraction, multiplication and integer conversions. Probe lines are
prefixed with `[FPUTRACE]`. Omit `FPU_TRACE=1` for a normal quiet model.

The freestanding userspace printf supports standard `%f` arguments. C promotes
FP32 values to binary64 at the variadic call boundary; the runtime consumes that
binary64 slot and formats the original FP32 value without requiring FP64
hardware. Width, zero padding and precisions from zero through nine are
supported.


Checkpoint and shutdown
=======================

Create or restore a simulator checkpoint with the options supported by the
run script:

  cd /mnt/fileserver/prj/dmctp/verification/simulator
  ./run --distributed --restore

Stop stale simulator processes before starting another instance:

  pkill -f "hostd.py" || true
  pkill Vsoc || true


Framebuffer demo
================

The distributed simulator exposes a 32x32 RGB332 framebuffer as /dev/fb0:

  cd /mnt/fileserver/prj/dmctp/verification/simulator
  ./run --distributed --graphics

From the DMCTP shell:

  run /bin/fb_demo.elf

The image is written to build/simulator/framebuffer.bmp. For browser viewing:

  cd /mnt/fileserver/prj/dmctp/verification/simulator
  ./scripts/view_framebuffer.sh 8088


Boot and memory flow
====================

  BL1 -> boot ROM SRAM bank hex files
  BL2/BL2A/kernel/user -> simulated block storage
  block storage -> page engine -> RAM
  distributed transfers -> NoM path where enabled
