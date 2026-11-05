ROOT := ../..
TARGET ?= soc
TARGETS := core memory soc sys_arr uart

.PHONY: all run check primitives clean $(TARGETS)
all: run
run:
	./scripts/run.sh $(TARGET)
check: run
primitives:
	python3 scripts/check_sync_cells.py
$(TARGETS):
	./scripts/run.sh $@
clean:
	rm -rf $(ROOT)/build/cdc
