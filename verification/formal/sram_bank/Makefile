OSS_CAD_SUITE ?= $(HOME)/tools/oss-cad-suite
ifneq ($(wildcard $(OSS_CAD_SUITE)/bin/sby),)
export PATH := $(OSS_CAD_SUITE)/bin:$(PATH)
endif

.PHONY: all prove cover clean

all: prove cover
prove:
	./scripts/run_prove.sh
cover:
	./scripts/run_cover.sh
clean:
	./scripts/clean.sh

