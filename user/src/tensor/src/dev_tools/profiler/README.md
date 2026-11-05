# Tensor profiler

`tensor-profiler` is a standalone collector and report program. Applications
contain no profiling calls. The tensor library emits automatic tracepoints when
the tool sets `TENSOR_TRACE_FILE`.

Run from `user/venv`:

```sh
cd user/venv
./profile run --all --trace tensor-trace.csv -- ./run ../src/image_processing/src/main.c
./profile attach PID 10
```

`run` captures the complete execution. `attach` toggles semantic tracing in an
already-running tensor process for the requested number of seconds.

Generated artifacts:

- `tensor-trace.csv`: raw, stable trace transport
- `tensor-trace.csv.roofline.csv`: kernel operational-intensity data
- `tensor-trace.csv.roofline.svg`: log-scale operational-intensity plot
- `tensor-trace.csv.flame.folded`: kernel-only folded timing data

Architecture-specific adapters live under `arch/`. The dependency-free core
does not link against `perf`, `nsys`, or `ncu`; adapters invoke those tools only
when requested.

```sh
./profile arch linux-cpu stat -- ./bin/main
./profile arch nvidia nsys -- ./bin/main
./profile arch nvidia ncu -- ./bin/main
```

Select only the report sections needed:

```sh
./profile report --time tensor-trace.csv
./profile report --jit --memory tensor-trace.csv
./profile report --graph --compute tensor-trace.csv
./profile report --roofline --flame tensor-trace.csv
```

Available flags are `--time`, `--jit`, `--memory`, `--graph`, `--compute`,
`--roofline`, `--flame`, and `--all`. Every report includes the overall
summary.

Report meanings:

- `--time` reports kernel calls separately from inclusive library calls.
  Inclusive library time can overlap kernel and JIT time and must not be added
  to those values.
- `--memory` separates external heap storage, memory-block handles, copies, and
  lazy-pool planned, committed, high-water, and unused capacity.
- `--graph` uses stable report-local node names (`N0`, `N1`, ...) and shows the
  operation, dtype, dependencies, execution count, and kernel time once per
  node. Raw pointer values are kept only in the trace transport.
- `--compute` reports traced input-plus-output tensor traffic. It is not a
  hardware DRAM-bandwidth measurement.
- `--roofline` uses the selected algorithm's validated `operations` hint from
  its `.op` source. Kernels whose algorithms perform no arithmetic correctly
  report zero operations and are omitted from the log-scale plot.
- `--flame` writes kernel timings only, avoiding double counting from inclusive
  graph and library scopes.

The summary distinguishes the complete capture span from the
first-to-last-kernel span and the sum of kernel call durations. These values
answer different questions and are not expected to be equal.
