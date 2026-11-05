# Makefile for Text Editor

TARGET ?= host

ifeq ($(TARGET),host)
CC = gcc
CFLAGS = -Wall -Wextra -O2
LDFLAGS =
else
LLVM_BIN = /mnt/fileserver/prj/dmctp/compiler/llvm-project/build/bin
CC = $(LLVM_BIN)/clang --target=riscv32
LLC = $(LLVM_BIN)/llc
LD = $(LLVM_BIN)/ld.lld
CFLAGS = -march=rv32im_zalrsc -mabi=ilp32 -ffreestanding -nostdlib -fno-builtin -O1 -Wall
endif

all: ../../bin/editor

../../bin/editor: build/editor.o
	mkdir -p ../../bin
ifeq ($(TARGET),host)
	$(CC) build/editor.o -o ../../bin/editor $(LDFLAGS)
else
	$(LD) -T ../../user/user.ld ../../user/crt0.o build/editor.o -o ../../bin/editor
endif

build/%.o: %.c
	@mkdir -p $(dir $@)
ifeq ($(TARGET),host)
	$(CC) $(CFLAGS) -c $< -o $@
else
	$(CC) $(CFLAGS) -S -emit-llvm $< -o build/$*.ll
	$(LLC) -march=dmctp32 -mattr=+m -filetype=obj build/$*.ll -o $@
endif

clean:
	rm -rf build/ ../../bin/editor
