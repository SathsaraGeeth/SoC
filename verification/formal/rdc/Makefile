OSS_CAD_SUITE ?= $(HOME)/tools/oss-cad-suite
ifneq ($(wildcard $(OSS_CAD_SUITE)/bin/sby),)
export PATH := $(OSS_CAD_SUITE)/bin:$(PATH)
endif

export SBY ?= sby
ROOT := ../../..
OUT := $(ROOT)/build/formal/rdc/prove/reset_sync

.PHONY: all prove clean
all: prove
prove:
	$(SBY) -d $(OUT) -f prove/reset_sync.sby
clean:
	find $(ROOT)/build/formal/rdc -depth -delete 2>/dev/null || true
