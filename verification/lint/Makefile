ROOT := ../..

TARGET ?= chip

include config/tops.mk

TOP_chip   := $(CHIP_TOP)
TOP_core   := $(CORE_TOP)
TOP_noc    := $(NOC_TOP)
TOP_memory := $(MEM_TOP)
TOP_uart   := $(UART_TOP)

TOP := $(TOP_$(TARGET))

.PHONY: all slang verilator verible yosys clean check_filelists

all: slang verilator verible yosys

slang:
	./slang/run.sh $(TARGET)

verilator:
	./verilator/run.sh $(TARGET) $(TOP)

verible:
	./verible/run.sh $(TARGET)

yosys:
	./yosys/run.sh $(TARGET)

check_filelists:
	python3 scripts/check_filelists.py

clean:
	rm -rf $(ROOT)/build/lint