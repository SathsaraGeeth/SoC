CC = /mnt/fileserver/prj/dmctp/compiler/llvm-project/build/bin/clang
MC = /mnt/fileserver/prj/dmctp/compiler/llvm-project/build/bin/llvm-mc
LD = /mnt/fileserver/prj/dmctp/compiler/llvm-project/build/bin/ld.lld

CFLAGS = --target=riscv64 -march=rv64im_zalrsc -mabi=lp64 -ffreestanding -nostdlib -fno-builtin -O0
MCFLAGS = -arch=dmctp64 -mattr=+zalrsc -filetype=obj
SEED ?= 1

all: boot_rom.elf

test.S: gen.py
	python3 gen.py 1000 $(SEED) > test.S

test.o: test.S
	$(CC) $(CFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

boot_rom.elf: test.o test.ld
	$(LD) -T test.ld -o $@ $<

clean:
	rm -f test.S test.o boot_rom.elf
