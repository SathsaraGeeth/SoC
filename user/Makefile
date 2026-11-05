# Top-level Makefile for Userspace

TARGET ?= host

SUBDIRS = src/tensor src/editor

.PHONY: all clean dmctp $(SUBDIRS)

all: $(SUBDIRS)

# Ensure src/tensor compiles first if other apps depend on libtensor
src/editor: src/tensor

$(SUBDIRS):
	$(MAKE) -C $@ TARGET=$(TARGET)

dmctp:
	$(MAKE) $(DMCTP_ELFS)

clean:
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	rm -rf $(DMCTP_BUILD_DIR) $(DMCTP_ELFS)

ROOT_DIR := ..
DMCTP_LLVM_BIN ?= $(ROOT_DIR)/compiler/llvm-project/build-experimental/bin
# Native DMCTP is the default userspace target. Select the stable
# RISC-V-compatible path explicitly with DMCTP_MODE=stable.
DMCTP_MODE ?= experimental

ifeq ($(DMCTP_MODE),experimental)
DMCTP_CC ?= $(DMCTP_LLVM_BIN)/clang
DMCTP_LD ?= $(DMCTP_LLVM_BIN)/ld.lld
DMCTP_MC ?= $(DMCTP_LLVM_BIN)/llvm-mc
DMCTP_ARCH_CFLAGS := --target=dmctpArch-dmctpVendor-dmctpOS
DMCTP_CRT0_SRC := src/lib/runtime/crt0_dmctp.S
DMCTP_CFLAGS_EXTRA := -DDMCTP_EXPERIMENTAL=1
DMCTP_MCFLAGS := -triple=dmctpArch-dmctpVendor-dmctpOS -mattr=+i,+m,+a,+system,+f -filetype=obj
else
DMCTP_CC ?= $(DMCTP_LLVM_BIN)/clang
DMCTP_LD ?= $(DMCTP_LLVM_BIN)/ld.lld
DMCTP_MC ?= $(DMCTP_CC)
DMCTP_ARCH_CFLAGS := --target=riscv64 -march=rv64i_zmmul_zalrsc -mabi=lp64
DMCTP_CRT0_SRC := src/lib/runtime/crt0.S
DMCTP_CFLAGS_EXTRA :=
endif

# Division and remainder deliberately lower to compiler-runtime routines.
DMCTP_CFLAGS := $(DMCTP_ARCH_CFLAGS) -ffreestanding -O2 -nostdlib -Iinclude -Iinclude/libc
ifneq ($(DMCTP_MODE),experimental)
DMCTP_CFLAGS += -mno-relax
endif
DMCTP_CFLAGS += $(DMCTP_CFLAGS_EXTRA)
DMCTP_LDFLAGS := -N -Ttext=0x00300000 --entry=_start
USER_HEADERS := $(shell find include -type f -name '*.h')

DMCTP_BUILD_DIR := build/dmctp
DMCTP_OBJ_DIR := $(DMCTP_BUILD_DIR)/obj
DMCTP_BIN_DIR := bin

# smpd_bench is temporarily excluded: the experimental backend does not yet
# lower the cttz operation emitted by this benchmark.
DMCTP_PROGRAMS ?= $(filter-out smpd_bench,$(sort $(basename $(notdir $(wildcard src/test_dmctp/*.c)))) init sh cat ls lscpu free nano)
DMCTP_ELFS := $(addprefix $(DMCTP_BIN_DIR)/,$(addsuffix .elf,$(DMCTP_PROGRAMS)))
DMCTP_COMMON_SRCS := \
 src/lib/syscall/syscalls.c \
	src/lib/memory/malloc.c \
	src/lib/math/fp8.c \
	src/lib/sysarr/sysarr.c \
	src/lib/compiler/compiler_rt.c
DMCTP_COMMON_OBJS := $(DMCTP_OBJ_DIR)/lib/runtime/crt0.o \
                    $(patsubst src/lib/%,$(DMCTP_OBJ_DIR)/lib/%,$(DMCTP_COMMON_SRCS:.c=.o))
DMCTP_COMMON_OBJS := $(DMCTP_COMMON_OBJS:.S=.o)

$(DMCTP_BIN_DIR)/%.elf: $(DMCTP_COMMON_OBJS) $(DMCTP_OBJ_DIR)/bin/%.o | $(DMCTP_BIN_DIR)
	$(DMCTP_LD) $(DMCTP_LDFLAGS) -o $@ $^

$(DMCTP_OBJ_DIR)/lib/%.o: src/lib/%.c Makefile
	@mkdir -p $(dir $@)
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

$(DMCTP_OBJ_DIR)/lib/%.o: src/lib/%.S Makefile
	@mkdir -p $(dir $@)
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

$(DMCTP_OBJ_DIR)/lib/runtime/crt0.o: $(DMCTP_CRT0_SRC) Makefile
	@mkdir -p $(dir $@)

ifeq ($(DMCTP_MODE),experimental)
	$(DMCTP_CC) $(DMCTP_CFLAGS) -E -x assembler-with-cpp $< | $(DMCTP_MC) $(DMCTP_MCFLAGS) -o $@

else
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

endif

$(DMCTP_OBJ_DIR)/bin/%.o: src/test_dmctp/%.c Makefile $(USER_HEADERS) | $(DMCTP_OBJ_DIR)/bin
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

$(DMCTP_OBJ_DIR)/bin/init.o: src/init/main.c Makefile $(USER_HEADERS) | $(DMCTP_OBJ_DIR)/bin
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

$(DMCTP_OBJ_DIR)/bin/sh.o: src/shell/main.c Makefile $(USER_HEADERS) | $(DMCTP_OBJ_DIR)/bin
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

$(DMCTP_OBJ_DIR)/bin/cat.o: src/coreutils/cat.c Makefile $(USER_HEADERS) | $(DMCTP_OBJ_DIR)/bin
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

$(DMCTP_OBJ_DIR)/bin/ls.o: src/coreutils/ls.c Makefile $(USER_HEADERS) | $(DMCTP_OBJ_DIR)/bin
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

$(DMCTP_OBJ_DIR)/bin/lscpu.o: src/procps/lscpu.c Makefile $(USER_HEADERS) | $(DMCTP_OBJ_DIR)/bin
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

$(DMCTP_OBJ_DIR)/bin/free.o: src/procps/free.c Makefile $(USER_HEADERS) | $(DMCTP_OBJ_DIR)/bin
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@

$(DMCTP_OBJ_DIR)/bin/nano.o: src/editor/nano.c Makefile $(USER_HEADERS) | $(DMCTP_OBJ_DIR)/bin
	$(DMCTP_CC) $(DMCTP_CFLAGS) -c $< -o $@


$(DMCTP_OBJ_DIR)/lib $(DMCTP_OBJ_DIR)/bin $(DMCTP_BIN_DIR):
	mkdir -p $@
