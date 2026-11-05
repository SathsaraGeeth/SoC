# Common lint configuration
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
LINT_DIR := $(ROOT)/verification/lint
BUILD_DIR := $(ROOT)/build/lint