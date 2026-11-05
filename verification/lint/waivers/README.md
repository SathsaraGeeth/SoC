# Waiver Register

This directory contains the central waiver register for all lint tools.

## Structure

- `waiver_register.yaml` - Human-readable YAML file documenting all waivers
- Tool-specific waiver files are in their respective directories:
  - `verilator/waivers/` - Verilator `.vlt` waiver files
  - `verible/waive.conf` - Verible waiver configuration
  - `slang/waivers.txt` - Slang waiver file

## Adding a Waiver

1. Add an entry to `waiver_register.yaml` with the reason and owner
2. Add the tool-specific waiver to the appropriate tool directory
3. Get the waiver reviewed and approved

## Waiver Lifecycle

- **active**: Currently in use
- **deprecated**: No longer needed, kept for history
- **removed**: Waiver has been removed