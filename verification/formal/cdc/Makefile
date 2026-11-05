OSS_CAD_SUITE ?= $(HOME)/tools/oss-cad-suite
ifneq ($(wildcard $(OSS_CAD_SUITE)/bin/sby),)
export PATH := $(OSS_CAD_SUITE)/bin:$(PATH)
endif

export SBY ?= sby
ROOT := ../../..
OUT := $(ROOT)/build/formal/cdc/prove/handshake

.PHONY: all prove clean
all: prove
prove:
	$(SBY) -d $(OUT) -f prove/handshake.sby
clean:
	find $(ROOT)/build/formal/cdc -depth -delete 2>/dev/null || true
