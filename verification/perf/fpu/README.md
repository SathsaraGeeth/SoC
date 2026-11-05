# FPU performance sweep

Run:

```sh
python3 verification/perf/fpu/perf.py
```

The harness builds the real `fpu` module with Verilator and measures timing at
its valid/ready interfaces. It does not calculate or compare arithmetic
results.

Pipeline cases submit twelve independent operations continuously. Latency is
the rising-edge distance from input acceptance to the matching output thread;
initiation interval is the mean distance between accepted inputs.

DIV and SQRT submit two operations as soon as lane 1 permits. Their report rows
include latency, initiation interval, and the number of cycles for which lane 1
rejects the waiting second request. Each iterative operation is measured with
lane 0 idle and continuously occupied, exposing the benefit of opportunistic
lane-0 use without checking result data.

The iterative sweep also measures FP32, FP16, BF16, FP8 E4M3, and FP8 E5M2.
The requested result precision selects three iterations for FP32, two for
FP16/BF16, and one for either FP8 format.

CSV, JSON, the Verilator build, and the standalone HTML report are written to
`build/perf/fpu/`.
