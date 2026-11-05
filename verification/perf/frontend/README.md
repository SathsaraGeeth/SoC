# Frontend performance sweep

`./perf.py` builds a standalone copy of the new frontend with exactly 32 hardware
contexts, then varies only the active context count through 1, 2, 4, 8, 16, and
32. It compiles `workload.c`, the packet-processing SMPD workload, and presents its
instruction image independently to every active hardware thread.

The JSON output contains per-cycle decoded-presentation histograms, per-thread
presentation and consumption counts, consume-to-refill latency distributions,
decoded-slot utilization, instruction-port utilization/acceptance, and request or
response backpressure. Run `python3 verification/perf/frontend/perf.py`.

The run also writes `verification/perf/frontend/report.html`, a self-contained visual
dashboard that can be opened with the VS Code Live Server extension. To regenerate
only the HTML from existing results, run:

`python3 verification/perf/frontend/perf.py --report-from build/perf/frontend-results.json`
