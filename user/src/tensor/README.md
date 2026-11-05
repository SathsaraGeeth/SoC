# Tensor JIT

Lazy API calls create graph nodes. During graph construction,
`tensor_jit_prepare()` compiles the required specialization. Materialization
validates buffers and obtains the already-compiled function with
`tensor_jit_get()`; it does not compile.

The cache key contains the kernel ID, target, output dtype/rank/full shape, and
the dtype/rank/full shape of every input. The cache compares the complete key,
not only its hash. Different keys can compile concurrently; requests for the
same key share one compilation.

`TENSOR_BACKEND=generic` uses scalar LLVM IR. `TENSOR_BACKEND=cpu` applies the
host-target LLVM optimization/vectorization pipeline and OpenMP chunking.

## CUDA backend

`TENSOR_BACKEND=cuda` keeps tensor storage on the selected CUDA device and
JIT-compiles the reachable, unmaterialized subgraph requested by each
`tensor_lazy_view_to()` into one NVPTX cooperative kernel. Host input views are
uploaded when attached and `tensor_lazy_view_to()` downloads only the requested
result. The CUDA Driver API is loaded from `libcuda.so.1`; applications must
link `libdl`, but do not need CUDA headers or `nvcc` to build the library.

Pointwise `.op` phases use a grid-stride loop. A software grid barrier separates
dependent phases, and launch dimensions are capped using cooperative occupancy
so every block is resident. Existing non-pointwise `.op` bodies retain their
ABI and currently execute on the grid leader; they can be given CUDA-parallel
algorithms in the operation compiler without changing the public API.

The backend currently accepts operations represented by `.op` bitcode. The
hand-written `src/kernels/dnn/*/host.c` operations need CUDA `.op` lowerings
before graphs containing them can be compiled. A missing lowering is reported
at the `view_to()` boundary. The device must support cooperative launch.

```bash
make TENSOR_BACKEND=cuda
```

## Add an operation

1. Register its API and graph operation in the domain `operations.def`.
2. Add `src/kernels/<domain>/<name>/<name>.op`:

```c
name: scale
id: 0x00010010

in x : T [**]
param factor : f32
out o : T [**]

pointwise:
  o = (T)(x * factor);
end
```

IDs are stable and unique. The parser derives a distinct specialization ID for
every dtype.
The `in`, `out`, and `param` declarations are also executable validation
rules: concrete dtypes are enforced, every `T` shares one dtype, repeated
dimension names must match, and parameter byte sizes are checked.
Use `[**]` for arbitrary rank with exact shape agreement. Ordinary shapes
such as `[M, K]` enforce rank and repeated symbolic dimensions.

At build time Clang compiles the C block once per dtype and the parser embeds
the LLVM bitcode in generated C. Runtime argument checks stay directly in the
operation's `api.c`. The generated registry only maps a kernel ID and dtype to
embedded bitcode; it has no runtime operation descriptor.

Use `pointwise:` when the body computes one output element. `T` is the tensor
dtype placeholder and the body must work unchanged for every tensor dtype.
Concrete types use the aliases from `dtype.h`, such as `int8`, `uint64`, and
`real32`.

Adjacent pointwise nodes with matching layouts are fused into one LLVM loop.
When a non-pointwise operation is dispatched, it counts compatible pointwise
hops in each input until it reaches the previous boundary, then compiles that
final chain. A terminal `tensor_lazy_view_to()` performs the same finalization
before starting the materialization timer. The result is cached by the kernel
sequence plus complete tensor signatures. The CPU backend vectorizes the fused
loop and executes it in OpenMP chunks.

3. Add one `api.c` containing the public lazy API, argument checks, and
   materialization adapter. Call `tensor_jit_get()` with the output and all
   inputs, then invoke the returned function. Elementwise APIs may divide work
   into OpenMP chunks after the single cache lookup.
4. Add all-dtype coverage to `src/jit/tests/`.

The Makefile discovers all `.op` files automatically. One parser invocation
emits their C descriptors and operation registry, and rejects duplicate names
or IDs. No Makefile rule or cache registry edit is needed for a new `.op`.

## Add a backend

Create `src/jit/gen/<backend>/` and implement:

```c
tensor_jit_kernel tensor_jit_compile(const char *name,
                                     const uint8_t *bitcode,
                                     extent bitcode_size,
                                     uint64_t signature_hash);
uint64_t tensor_jit_target_hash(void);
void tensor_jit_shutdown(void);
```

The backend receives common LLVM IR, applies its target optimization pipeline,
and adds the module to ORC v2. Add only the backend sources and flags to the
`TENSOR_BACKEND` Makefile selection.

## Validate

```bash
make TENSOR_BACKEND=generic test
make TENSOR_BACKEND=cpu test

cd /mnt/fileserver/prj/dmctp/user/venv
TENSOR_BACKEND=cpu ./run ../src/image_processing/src/main.c
TENSOR_BACKEND=cpu ./run ../src/isp_pipe/main/main.c
TENSOR_BACKEND=cpu ./run ../src/yolo
```

Profiler output reports preparation/cache lookup, ORC compilation, runtime
cache lookup, and materialization separately.
