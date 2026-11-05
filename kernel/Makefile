
LLVM_BIN ?= /mnt/fileserver/prj/dmctp/compiler/llvm-project/build-experimental/bin
TRIPLE   := dmctpArch-dmctpVendor-dmctpOS
CC       := $(LLVM_BIN)/clang --target=$(TRIPLE)
MC       := $(LLVM_BIN)/llvm-mc
LD       := $(LLVM_BIN)/ld.lld
OBJCOPY  := $(LLVM_BIN)/llvm-objcopy


CFLAGS  := \
    -ffreestanding          \
    -nostdlib               \
    -fno-builtin            \
    -O1 -Wall               \
    -DVERILATOR=1           \
    -I.                     \
    -Iinclude               \
    -Isync                  \
    -Idmtcp/include         \
    -Iboot/common

KERNEL_TRAP_DBG ?= 0
ifeq ($(KERNEL_TRAP_DBG),1)
CFLAGS += -DKERNEL_TRAP_DBG=1
endif

ASFLAGS := $(CFLAGS) -x assembler-with-cpp
MCFLAGS := -triple=$(TRIPLE) -mattr=+i,+m,+a,+system,+f -filetype=obj

LDSCRIPT := boot/bl1/bl1.ld

BUILD_DIR := build
SYNC_STAMP := $(BUILD_DIR)/truth_sync.stamp

OBJS :=  $(BUILD_DIR)/boot/bl1/head.o                 \
         $(BUILD_DIR)/drivers/uart/uart.o             \
         $(BUILD_DIR)/boot/common/load.o              \
         $(BUILD_DIR)/boot/common/console_early.o        \
         $(BUILD_DIR)/boot/common/nom.o               \
         $(BUILD_DIR)/boot/common/nom_msg.o           \
         $(BUILD_DIR)/boot/common/nom_transfer.o      \
         $(BUILD_DIR)/boot/bl2/sync/spinlock.o        \
         $(BUILD_DIR)/boot/bl1/nom/nom.o              \
         $(BUILD_DIR)/boot/bl1/bl1_main.o

BL2_OBJS := $(BUILD_DIR)/boot/bl2/bl2_head.o \
            $(BUILD_DIR)/boot/bl2/bl2_main.o \
            $(BUILD_DIR)/boot/bl2/trap/trap.o \
            $(BUILD_DIR)/boot/bl2/trap/trap_handler.o \
            $(BUILD_DIR)/boot/bl2/mm/heap.o \
            $(BUILD_DIR)/boot/bl2/smp/smp.o \
            $(BUILD_DIR)/boot/bl2/smp/smp_asm.o \
            $(BUILD_DIR)/boot/bl2/sync/spinlock.o \
            $(BUILD_DIR)/boot/common/load.o \
            $(BUILD_DIR)/boot/common/console_early.o \
            $(BUILD_DIR)/drivers/uart/uart.o

BL2A_OBJS := $(BUILD_DIR)/boot/bl2A/bl2_head.o \
             $(BUILD_DIR)/boot/bl2A/bl2_main.o \
             $(BUILD_DIR)/boot/bl2A/trap/trap.o \
             $(BUILD_DIR)/boot/bl2A/trap/trap_handler.o \
             $(BUILD_DIR)/boot/bl2A/mm/heap.o \
             $(BUILD_DIR)/boot/bl2A/smp/smp.o \
             $(BUILD_DIR)/boot/bl2A/smp/smp_asm.o \
             $(BUILD_DIR)/boot/bl2A/sync/spinlock.o \
             $(BUILD_DIR)/boot/common/load.o \
             $(BUILD_DIR)/boot/common/console_early.o \
             $(BUILD_DIR)/drivers/uart/uart.o

KERNEL_OBJS := $(BUILD_DIR)/init/kernel_head.o \
               $(BUILD_DIR)/init/kernel_main.o \
               $(BUILD_DIR)/proc/process.o \
               $(BUILD_DIR)/proc/exec/exec.o \
               $(BUILD_DIR)/proc/exit/exit.o \
               $(BUILD_DIR)/proc/fork/fork.o \
               $(BUILD_DIR)/proc/wait/wait.o \
               $(BUILD_DIR)/proc/signal/signal.o \
               $(BUILD_DIR)/proc/ipc/pipe.o \
               $(BUILD_DIR)/proc/ipc/shm.o \
               $(BUILD_DIR)/proc/sched/core.o \
               $(BUILD_DIR)/proc/sched/fair/fair.o \
               $(BUILD_DIR)/proc/sched/pid.o \
               $(BUILD_DIR)/proc/sched/process.o \
               $(BUILD_DIR)/proc/syscalls.o \
               $(BUILD_DIR)/proc/ipc/syscalls.o \
               $(BUILD_DIR)/proc/signal/syscalls.o \
               $(BUILD_DIR)/lib/printf.o \
               $(BUILD_DIR)/lib/string.o \
               $(BUILD_DIR)/lib/printk.o \
               $(BUILD_DIR)/boot/common/console_early.o \
               $(BUILD_DIR)/smp/smp.o \
               $(BUILD_DIR)/smp/smp_asm.o \
               $(BUILD_DIR)/mm/slab.o \
               $(BUILD_DIR)/proc/sched/context_switch.o \
               $(BUILD_DIR)/proc/exec/user_enter.o \
               $(BUILD_DIR)/syscall/syscall.o \
               $(BUILD_DIR)/syscall/syscall_table.o \
               $(BUILD_DIR)/syscall/usercopy.o \
               $(BUILD_DIR)/trap/entry.o \
               $(BUILD_DIR)/trap/trap.o \
               $(BUILD_DIR)/fs/file.o \
               $(BUILD_DIR)/fs/vfs.o \
               $(BUILD_DIR)/fs/blockfs.o \
               $(BUILD_DIR)/fs/syscalls.o \
               $(BUILD_DIR)/drivers/core/dev.o \
               $(BUILD_DIR)/drivers/uart/uart_dev.o \
               $(BUILD_DIR)/drivers/video/framebuffer_dev.o \
               $(BUILD_DIR)/drivers/sysarr/sys_array_dev.o \
               $(BUILD_DIR)/irq/irq.o \
               $(BUILD_DIR)/sync/atomic/atomic.o \
               $(BUILD_DIR)/sync/barrier/barrier.o \
               $(BUILD_DIR)/sync/bitops/bitops.o \
               $(BUILD_DIR)/sync/completion/completion.o \
               $(BUILD_DIR)/sync/futex/futex.o \
               $(BUILD_DIR)/sync/lockdep/lockdep.o \
               $(BUILD_DIR)/sync/mutex/mutex.o \
               $(BUILD_DIR)/sync/percpu/percpu.o \
               $(BUILD_DIR)/sync/qspinlock/qspinlock.o \
               $(BUILD_DIR)/sync/rcu/rcu.o \
               $(BUILD_DIR)/sync/rwlock/rwlock.o \
               $(BUILD_DIR)/sync/rwsem/rwsem.o \
               $(BUILD_DIR)/sync/semaphore/semaphore.o \
               $(BUILD_DIR)/sync/seqlock/seqlock.o \
               $(BUILD_DIR)/sync/spinlock/spinlock.o \
               $(BUILD_DIR)/sync/waitqueue/waitqueue.o \
               $(BUILD_DIR)/drivers/uart/uart.o \
               $(BUILD_DIR)/drivers/timer/timer.o \
               $(BUILD_DIR)/drivers/timer/syscalls.o \
               $(BUILD_DIR)/smp/syscalls.o \
               $(BUILD_DIR)/mm/memory.o \
               $(BUILD_DIR)/mm/mapping.o \
               $(BUILD_DIR)/mm/page.o \
               $(BUILD_DIR)/mm/frame.o \
               $(BUILD_DIR)/mm/clock.o \
               $(BUILD_DIR)/mm/page_msg.o \
               $(BUILD_DIR)/mm/fault.o \
               $(BUILD_DIR)/mm/syscalls.o

all: $(SYNC_STAMP) $(BUILD_DIR)/boot_rom.bin $(BUILD_DIR)/bl2.elf $(BUILD_DIR)/bl2.bin $(BUILD_DIR)/bl2A.elf $(BUILD_DIR)/bl2A.bin $(BUILD_DIR)/kernel.bin

$(SYNC_STAMP): ../regressions/truth/sync.sh ../regressions/truth/soc.yaml ../rtl/isa/isa.yaml
	@mkdir -p $(dir $@)
	cd .. && ./regressions/truth/sync.sh
	@touch $@

# assembly → .o
$(BUILD_DIR)/boot/bl1/head.o: boot/bl1/bl1_head.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/init/kernel_head.o: init/kernel_head.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/boot/bl2/smp/smp_asm.o: boot/bl2/smp/smp_asm.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/smp/smp_asm.o: smp/smp.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/boot/bl2/bl2_head.o: boot/bl2/bl2_head.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/boot/bl2A/smp/smp_asm.o: boot/bl2A/smp/smp_asm.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/boot/bl2A/bl2_head.o: boot/bl2A/bl2_head.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/trap/entry.o: trap/entry.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/proc/sched/context_switch.o: proc/sched/context_switch.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/proc/exec/user_enter.o: proc/exec/user_enter.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/boot/bl2/trap/trap.o: boot/bl2/trap/trap.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/boot/bl2A/trap/trap.o: boot/bl2A/trap/trap.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/irq/irq.o: irq/irq.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/sync/atomic/atomic.o: sync/atomic/atomic.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/sync/barrier/barrier.o: sync/barrier/barrier.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

$(BUILD_DIR)/sync/bitops/bitops.o: sync/bitops/bitops.S $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< | $(MC) $(MCFLAGS) -o $@

# C → native DMCTP object
$(BUILD_DIR)/%.o: %.c $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Preprocess linker scripts
$(BUILD_DIR)/boot/bl1/bl1.ld.preprocessed: boot/bl1/bl1.ld $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< -o $@

$(BUILD_DIR)/boot/bl2/bl2.ld.preprocessed: boot/bl2/bl2.ld $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< -o $@

$(BUILD_DIR)/boot/bl2A/bl2.ld.preprocessed: boot/bl2A/bl2.ld $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< -o $@

$(BUILD_DIR)/kernel.ld.preprocessed: kernel.ld $(SYNC_STAMP)
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) -E $< -o $@

# link
$(BUILD_DIR)/boot_rom.elf: $(OBJS) $(BUILD_DIR)/boot/bl1/bl1.ld.preprocessed
	@mkdir -p $(dir $@)
	$(LD) -T $(BUILD_DIR)/boot/bl1/bl1.ld.preprocessed -o $@ $(OBJS)

$(BUILD_DIR)/bl2.elf: $(BL2_OBJS) $(BUILD_DIR)/boot/bl2/bl2.ld.preprocessed
	@mkdir -p $(dir $@)
	$(LD) -T $(BUILD_DIR)/boot/bl2/bl2.ld.preprocessed -o $@ $(BL2_OBJS)

$(BUILD_DIR)/bl2A.elf: $(BL2A_OBJS) $(BUILD_DIR)/boot/bl2A/bl2.ld.preprocessed
	@mkdir -p $(dir $@)
	$(LD) -T $(BUILD_DIR)/boot/bl2A/bl2.ld.preprocessed -o $@ $(BL2A_OBJS)

$(BUILD_DIR)/kernel.elf: $(KERNEL_OBJS) $(BUILD_DIR)/kernel.ld.preprocessed
	@mkdir -p $(dir $@)
	$(LD) -T $(BUILD_DIR)/kernel.ld.preprocessed -o $@ $(KERNEL_OBJS)

# raw binary
$(BUILD_DIR)/boot_rom.bin: $(BUILD_DIR)/boot_rom.elf
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/bl2.bin: $(BUILD_DIR)/bl2.elf
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/bl2A.bin: $(BUILD_DIR)/bl2A.elf
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/kernel.bin: $(BUILD_DIR)/kernel.elf
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary $< $@
	@mkdir -p ../verification/simulator/build/hostroot
	cp $@ ../verification/simulator/build/hostroot/kernel.bin

clean:
	rm -rf $(BUILD_DIR)
