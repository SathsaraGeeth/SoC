# sys_core performance sweep

Run:

```sh
python3 verification/perf/sys_core/perf.py
```

The C++ runner drives the real four-word MMIO command interface: delegation,
operation, writeback, and release. Workloads are the assembly-like files in
`workloads/`; `perf.py` parses and packs them into the command image. Reusable
C++ driver methods issue commands, advance clocks, and service memory.
Read responses use a deterministic LFSR-selected latency of 4–10 cycles.
Writes are accepted immediately because this sweep measures command and read
traffic behavior, not functional correctness.

The long matched pair performs one 256x256 INT8 multiplication. Dense mode uses
one 32x32-tile operation command. Native mode software-sequences 1,024 output
tiles; each output uses 32 operation commands with `start` on the first and
`last` on the final reduction tile, followed by one writeback. The complete
stream is submitted through the real MMIO command interface and its normal
command-FIFO backpressure.

The report reads the exported `perf_vec` counters. A/B load and D store values
are accepted memory-interface transactions; they do not include internal reuse
markers. The packed FIFO field contains instantaneous levels, which are sampled
every 10 cycles through job completion and a 320-cycle drain window. Peaks are
calculated by the C++ runner rather than stored in RTL. The report includes an
occupancy heatmap and reports raw counters, per-port bandwidth against the 8 GB/s
theoretical limit, observed TOPS, and usage of the 0.128 TOPS compute peak.

The runner writes the parsed command image, CSV results, JSON results, and a
standalone report under `build/perf/sys_core/`.
