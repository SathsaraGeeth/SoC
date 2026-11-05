ROOT := ../..
TARGET ?= soc
TARGETS := core memory soc sys_arr uart

.PHONY: all run check clean $(TARGETS)
all: run
run:
	./scripts/run.sh $(TARGET)
check: run
$(TARGETS):
	./scripts/run.sh $@
clean:
	rm -rf $(ROOT)/build/rdc
