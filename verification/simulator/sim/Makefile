# Makefile for pure C++ SoC testbench using verilator
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
# Makefile paths must not depend on the caller's $PWD (for example, `make -C`).
PWD := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(abspath $(PWD)/../../..)
BUILD_DIR := $(REPO_ROOT)/build/simulator

# Paths relative to the verification/simulator/sim directory
VERILOG_SOURCES += $(PWD)/../../../rtl/isa/isa_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/fpu/fpu_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/fpu/fpu_functions_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/common/reset/reset_sync.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/core_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/soc/topology_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/memory/memory_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/soc/soc_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/alu.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/common/fifo/circular_buffer.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/csr.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/decoder.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/regfile.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/fpu/fpu_iter.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/fpu/fpu.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/fpu.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/core/core.sv

VERILOG_SOURCES += $(PWD)/../../../rtl/memory/sram_bank.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/memory/page_engine.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/memory/memory.sv

VERILOG_SOURCES += $(PWD)/../../../rtl/sys_arr/sys_cnfg_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/sys_arr/mac_fp8_fp8_fp8_61_cnfg_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/sys_arr/common.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/sys_arr/mac20i_v2.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/sys_arr/mac_fp8_fp8_fp8_61_v2.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/sys_arr/mmacu_core_v2.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/sys_arr/sys_address_generator.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/sys_arr/sys_core.sv

VERILOG_SOURCES += $(PWD)/../../../rtl/timer/timer.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/uart/uart.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/uart/uart_mmio.sv
VERILOG_SOURCES += $(PWD)/../../../rtl/soc/router.sv

TOP_MODULE ?= soc
VERILOG_SOURCES += $(PWD)/../../../rtl/soc/$(TOP_MODULE).sv

# Verilator specific arguments
MOCK_CORE ?= 0
VERILATOR_JOBS ?= $(shell nproc)
VERILATOR_THREADS ?= 2
VERILATOR_MAX_MTASKS ?= 64
VERILATOR_OPT ?= -O3
SIM_CFLAGS ?= -O3 -march=native -flto
export MOCK_CORE
EXTRA_ARGS += -Wno-fatal $(VERILATOR_OPT) -CFLAGS "$(SIM_CFLAGS)" \
	--threads $(VERILATOR_THREADS) --threads-max-mtasks $(VERILATOR_MAX_MTASKS) \
	--output-split 10000 --output-split-cfuncs 100 -DVERILATOR=1 --savable
ifneq ($(FLASH_SIZE),)
EXTRA_ARGS += -CFLAGS "-DFLASH_SIZE=$(FLASH_SIZE)"
endif
ifneq ($(BL2_BASE_BA),)
EXTRA_ARGS += -CFLAGS "-DBL2_BASE_BA=$(BL2_BASE_BA)"
endif
ifneq ($(BL2A_BASE_BA),)
EXTRA_ARGS += -CFLAGS "-DBL2A_BASE_BA=$(BL2A_BASE_BA)"
endif
ifneq ($(KERNEL_BASE_BA),)
EXTRA_ARGS += -CFLAGS "-DKERNEL_BASE_BA=$(KERNEL_BASE_BA)"
endif
ifneq ($(FS_BASE_BA),)
EXTRA_ARGS += -CFLAGS "-DFS_BASE_BA=$(FS_BASE_BA)"
endif
ifneq ($(NUM_BANKS),)
EXTRA_ARGS += -CFLAGS "-DPAGE_LINE_WORDS=$(NUM_BANKS)"
endif
ifneq ($(CLOCK_FREQ_HZ),)
EXTRA_ARGS += -CFLAGS "-DCLOCK_FREQ_HZ=$(CLOCK_FREQ_HZ)"
endif
ifeq ($(FPU_TRACE), 1)
EXTRA_ARGS += -DDMCTP_FPU_TRACE=1
endif


ifeq ($(MOCK_CORE), 1)
EXTRA_ARGS += -DMOCK_CORE=1
endif

all:
	mkdir -p $(BUILD_DIR)/obj_dir
	verilator --Mdir $(BUILD_DIR)/obj_dir --cc --exe --build -j $(VERILATOR_JOBS) sim_main.cpp $(VERILOG_SOURCES) --top-module $(TOP_MODULE) --prefix Vsoc $(EXTRA_ARGS)

clean:
	rm -rf $(BUILD_DIR)
