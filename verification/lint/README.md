# Lint Infrastructure

This directory contains the lint infrastructure for the DMCTP project.

## Directory Structure

```
verification/lint/
├── README.md           # This file
├── Makefile            # Top-level lint Makefile
├── config/             # Shared configuration
│   ├── common.mk       # Common Makefile variables
│   ├── tops.mk         # Top-level module names
│   └── defines.f       # Shared compile defines
├── filelists/          # File lists for each target
│   ├── common.f        # Shared packages and common RTL
│   ├── chip.f          # Full chip
│   ├── core.f          # Core block
│   ├── noc.f           # NOC block
│   ├── memory.f        # Memory subsystem
│   └── uart.f          # UART block
├── slang/              # Slang (SystemVerilog lint)
│   ├── run.sh          # Runner script
│   ├── common.args     # Shared arguments
│   ├── chip.args       # Chip-specific arguments
│   └── waivers.txt     # Waiver file
├── verilator/          # Verilator lint
│   ├── run.sh          # Runner script
│   ├── common.vlt      # Common waivers
│   ├── chip.vlt        # Chip waivers
│   └── waivers/        # Detailed waiver files
│       ├── common.vlt
│       └── chip.vlt
├── verible/            # Verible lint (formatting/style)
│   ├── run.sh          # Runner script
│   ├── rules.conf      # Rule configuration
│   ├── waive.conf      # Waiver configuration
│   └── file_excludes.txt
├── yosys/              # Yosys lint (structural)
│   ├── run.sh          # Runner script
│   ├── common.ys       # Common script
│   ├── chip.ys         # Chip script
│   └── blocks/         # Block-specific scripts
│       ├── core.ys
│       ├── noc.ys
│       ├── memory.ys
│       └── uart.ys
├── scripts/            # Utility scripts
│   ├── run_all.sh      # Run all tools for a target
│   ├── run_block.sh    # Run a specific tool/block
│   ├── check_filelists.py  # Validate filelists
│   └── summarize.py    # Summarize results
└── waivers/            # Central waiver register
    ├── README.md
    └── waiver_register.yaml
```

## Usage

### Full chip lint
```bash
make -C verification/lint
# or from root:
make lint
```

### Block-level lint
```bash
make -C verification/lint TARGET=uart
make -C verification/lint TARGET=core
make -C verification/lint TARGET=memory
make -C verification/lint TARGET=noc
```

### Run one tool only
```bash
make -C verification/lint TARGET=uart verilator
make -C verification/lint TARGET=chip slang
```

### Using scripts directly
```bash
# Run all tools for chip target
./verification/lint/scripts/run_all.sh chip

# Run verilator for uart block
./verification/lint/scripts/run_block.sh uart verilator

# Check filelists
./verification/lint/scripts/check_filelists.py

# Summarize results (after running lint)
./verification/lint/scripts/summarize.py
```

### Clean build artifacts
```bash
make -C verification/lint clean
```

## Tools

| Tool       | Focus                                          |
|------------|------------------------------------------------|
| Slang      | Syntax, type checking, package resolution      |
| Verilator  | Warnings, unused signals, style issues         |
| Verible    | Formatting, naming conventions, code style     |
| Yosys      | Hierarchy, missing modules, structural issues  |

## Output Directory

Generated files go to `build/lint/`:
```
build/lint/
├── slang/          # Slang lint logs
├── verilator/      # Verilator lint logs
├── verible/        # Verible lint logs
├── yosys/          # Yosys lint logs
└── summary/        # Summary reports
```

## Adding a New Target

1. Create `filelists/<target>.f` with the file list
2. Create `yosys/blocks/<target>.ys` if using Yosys
3. Add target to `Makefile` TARGET_* variable mapping
4. Add top module to `config/tops.mk`