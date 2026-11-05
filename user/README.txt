# DMCTP User Space

This tree contains user-space code that can run in two ways:

- on DMCTP, built as freestanding RISC-V ELF binaries and packed into the simulator file system
- on the host, built and run through `venv/` for fast development

The source layout is shared. The venv provides the host abstraction; source files do not need a separate host copy.

## Layout

```text
bin/              DMCTP target ELF output
build/            build artifacts
include/          public user-space headers
include/sys/      syscall numbers and basic system types
include/tensor/   tensor public headers
lib/              built libraries
src/lib/          DMCTP runtime and host syscall shim
src/test_dmctp/   small DMCTP user-space tests
src/tensor/       tensor runtime and tests
src/isp_pipe/     ISP pipeline apps
src/editor/       editor app
venv/             host build/run wrapper and host-only headers
```

## Run On DMCTP

Build the DMCTP user-space tests:

```sh
cd /mnt/fileserver/prj/dmctp/user
make dmctp
```

This builds:

```text
bin/utest.elf
bin/test_timer.elf
bin/test_sys.elf
bin/test_sys_fp.elf
bin/arithm_test.elf
```

The simulator automatically builds these and packs them into the block file system:

```sh
cd /mnt/fileserver/prj/dmctp/verification/simulator
./run.sh --distributed
```

From the DMCTP shell, run the installed binaries by path, for example:

```text
run /bin/utest.elf
run /bin/test_timer.elf
run /bin/arithm_test.elf
```

The systolic-array tests are also built into the image:

```text
run /bin/test_sys.elf
run /bin/test_sys_fp.elf
```

They require the DMCTP systolic-array device and are not expected to run from the host venv.

The systolic-array user API is exposed by `include/sysarr/sysarr.h` and implemented in
`src/lib/sysarr.c`. It reports the synced hardware capability with
`sysarr_get_caps()`, rejects incompatible type/size requests with
`sysarr_supports()`, and submits batches of tile commands in one `/dev/sysarr0`
write. Use `sysarr_make_chain_request()` when a caller wants to set the
hardware reduction-chain length explicitly.

## Run On Host Through venv

Use `user/venv/run` for host builds. It compiles the requested source or directory and writes host binaries under `user/venv/bin/`.

Run the DMCTP smoke test on the host:

```sh
cd /mnt/fileserver/prj/dmctp/user/venv
./run ../src/test_dmctp/utest.c
```

Run the timer test on the host:

```sh
cd /mnt/fileserver/prj/dmctp/user/venv
./run ../src/test_dmctp/test_timer.c
```

The venv maps DMCTP-only helpers such as `get_time()` through `src/lib/host_syscalls.c`.

## venv Regression Targets

The venv Makefile keeps common host runs as targets:

```sh
cd /mnt/fileserver/prj/dmctp/user/venv
make dmctp
make dmctp_timer
make yolo
make isp
```

Run the current host regression set:

```sh
cd /mnt/fileserver/prj/dmctp/user/venv
make dmctp dmctp_timer yolo isp
```

Useful app targets:

```text
make yolo       runs src/yolo
make isp        runs src/isp_pipe/main/main.c
make raw_only   runs src/isp_pipe/main/main_raw_only.c
```

## Clean

Clean target DMCTP user-space outputs:

```sh
cd /mnt/fileserver/prj/dmctp/user
make clean
```

Clean host venv outputs:

```sh
cd /mnt/fileserver/prj/dmctp/user/venv
make clean
```
