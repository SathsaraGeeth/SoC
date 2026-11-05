#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# visible.sh
#
# Visualize one .op file going through the operation compiler.
#
# Usage: ./visible.sh path/to/file.op
#
# Output: visible_<operation>.txt
#
# Pipeline shown:
#
#   .op source
#       ↓
#   lexer
#       ↓
#   parser / AST
#       ↓
#   validator / resolved operation
#       ↓
#   dtype specialization
#       ↓
#   generated C-like lowering
#       ↓
#   LLVM bitcode
#       ↓
#   textual LLVM IR
#       ↓
#   generated registry
#
# =============================================================================

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <operation.op>" >&2
    exit 1
fi

OP_FILE="$(realpath "$1")"

if [[ ! -f "$OP_FILE" ]]; then
    echo "error: file does not exist: $OP_FILE" >&2
    exit 1
fi

if [[ "${OP_FILE##*.}" != "op" ]]; then
    echo "error: input must be a .op file" >&2
    exit 1
fi

# visible.sh:
#
#   tensor/src/op_parser/__tests__/visible.sh
#
# parser directory:
#
#   tensor/src/op_parser
PARSER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BASENAME="$(basename "$OP_FILE" .op)"
OUTPUT="$(pwd)/visible_${BASENAME}.txt"

TMP="$(mktemp -d -t tensor-op-visible-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

GENERATED_C="$TMP/operations.c"
BITCODE="$TMP/operations.bc"
LLVM_IR="$TMP/operations.ll"
REGISTRY="$TMP/registry.c"

export OP_FILE
export PARSER_DIR
export GENERATED_C
export BITCODE
export LLVM_IR
export REGISTRY

export PYTHONPATH="$PARSER_DIR${PYTHONPATH:+:$PYTHONPATH}"

divider()
{
    printf '\n'
    printf '%s\n' \
        '================================================================================'
}

section()
{
    divider
    printf '%s\n' "$1"
    printf '%s\n' \
        '================================================================================'
    printf '\n'
}

{
    echo "TENSOR .op COMPILER — VISIBLE PIPELINE"
    echo
    echo "Input  : $OP_FILE"
    echo "Parser : $PARSER_DIR"
    echo "Output : $OUTPUT"

    # =========================================================================
    section "STEP 0 — ORIGINAL .op SOURCE"

    cat "$OP_FILE"

    # =========================================================================
    section "STEP 1 — LEXER OUTPUT"

    python3 <<'PY'
import os
from pathlib import Path

from lexer import AlgorithmBlock, Line, lex

path = Path(os.environ["OP_FILE"])

items = lex(path)

print(f"lex({path})")
print(f"item count: {len(items)}")
print()

for index, item in enumerate(items):
    print("-" * 80)
    print(f"ITEM {index}")
    print()

    if isinstance(item, Line):
        print("kind : Line")
        print(f"line : {item.number}")
        print(f"text : {item.text!r}")

    elif isinstance(item, AlgorithmBlock):
        print("kind : AlgorithmBlock")
        print(f"line : {item.number}")
        print(f"name : {item.name}")
        print()
        print("body:")
        print(item.body)

    else:
        print(repr(item))
PY

    # =========================================================================
    section "STEP 2 — PARSER OUTPUT / RAW AST"

    python3 <<'PY'
import os
import pprint
from pathlib import Path

from parser import parse

operation = parse(Path(os.environ["OP_FILE"]))

print("parse(path) -> Operation")
print()

pprint.pp(
    operation,
    width=120,
    sort_dicts=False,
)
PY

    # =========================================================================
    section "STEP 3 — AST BROKEN DOWN"

    python3 <<'PY'
import os
from pathlib import Path

from parser import parse

op = parse(Path(os.environ["OP_FILE"]))

print("OPERATION")
print(f"  source : {op.source}")
print(f"  name   : {op.name}")
print(f"  id     : 0x{op.id:08x}")
print()

print("TYPES")
if not op.types:
    print("  <none>")

for name, value in op.types.items():
    print(f"  {name}")
    print(f"    dtypes = {value.dtypes}")

print()

print("DEVICE SET DEFINITIONS")
if not op.devices:
    print("  <none>")

for name, value in op.devices.items():
    print(f"  {name}")
    print(f"    members = {value.devices}")

print()

print("DIMENSIONS")
if not op.dimensions:
    print("  <none>")

for name, value in op.dimensions.items():
    print(f"  {name} = {value.value!r}")

print()

print("SHAPES")
if not op.shapes:
    print("  <none>")

for name, value in op.shapes.items():
    print(f"  {name} = {value.dimensions}")

print()

print("VALUES")

for value in op.values:
    print(
        f"  {value.kind:5} "
        f"{value.name:20} "
        f"type={value.type_name:12} "
        f"shape={value.shape!r} "
        f"count={value.count}"
    )

print()

print("ALGORITHMS")

for algorithm in op.algorithms:
    print()
    print(f"  algorithm {algorithm.name}")
    print("  " + "-" * 70)

    for line in algorithm.body.splitlines():
        print(f"    {line}")

print()

print("HINTS")
print(f"  pointwise    = {op.hints.pointwise}")
print(f"  targets      = {op.hints.targets}")
print(f"  operations   = {op.hints.operations}")
print(f"  requirements = {op.hints.requirements}")
print(f"  preferences  = {op.hints.preferences}")
PY

    # =========================================================================
    section "STEP 4 — VALIDATOR OUTPUT / RESOLVED OPERATION"

    python3 <<'PY'
import os
import pprint
from pathlib import Path

from parser import parse
from validator import validate

ast = parse(Path(os.environ["OP_FILE"]))
op = validate(ast)

print("validate(parse(path)) -> ValidatedOperation")
print()

pprint.pp(
    op,
    width=120,
    sort_dicts=False,
)

print()
print("=" * 80)
print("RESOLVED VALUES")
print("=" * 80)
print()

for value in op.values:
    print(f"name     : {value.name}")
    print(f"kind     : {value.kind}")
    print(f"type_key : {value.type_key}")
    print(f"dtypes   : {value.dtypes}")
    print(f"shape    : {value.shape}")
    print(f"count    : {value.count}")
    print()

print("=" * 80)
print("RESOLVED TARGET SETS")
print("=" * 80)
print()

for algorithm, targets in op.targets.items():
    print(f"{algorithm}: {targets}")
PY

    # =========================================================================
    section "STEP 5 — DTYPE SPECIALIZATION ASSIGNMENTS"

    python3 <<'PY'
import os
from pathlib import Path

from parser import parse
from validator import validate
from ir import _assignments

op = validate(parse(Path(os.environ["OP_FILE"])))

assignments = list(_assignments(op))

print(f"specialization count: {len(assignments)}")
print()

for index, assignment in enumerate(assignments):
    print(f"SPECIALIZATION {index}")

    if not assignment:
        print("    <no selectable dtype variables>")
    else:
        for type_name, dtype in assignment.items():
            print(f"    {type_name} -> {dtype}")

    print()
PY

    # =========================================================================
    section "STEP 6 — LOWERED BINDINGS FOR EACH DTYPE SPECIALIZATION"

    python3 <<'PY'
import os
from pathlib import Path

from parser import parse
from validator import validate
from ir import _assignments, _bindings

op = validate(parse(Path(os.environ["OP_FILE"])))

for index, assignment in enumerate(_assignments(op)):
    print("=" * 80)
    print(f"SPECIALIZATION {index}")
    print("=" * 80)
    print()

    print(f"assignment: {assignment}")
    print()

    declarations, dimensions = _bindings(op, assignment)

    print("GENERATED C BINDINGS")
    print()

    for declaration in declarations:
        print(declaration)

    print()
    print("DIMENSION ARRAY VALUES")
    print()

    if dimensions:
        for i, expression in enumerate(dimensions):
            print(f"  dimensions[{i}] = {expression}")
    else:
        print("  <none>")

    print()
PY

    # =========================================================================
    section "STEP 7 — ALGORITHM BODIES AS SEEN BY THE LOWERER"

    python3 <<'PY'
import os
from pathlib import Path

from parser import parse
from validator import validate

op = validate(parse(Path(os.environ["OP_FILE"])))

for index, algorithm in enumerate(op.ast.algorithms):
    print("=" * 80)
    print(f"ALGORITHM {index}: {algorithm.name}")
    print("=" * 80)
    print()

    print("original body:")
    print()

    print(algorithm.body)

    print()
    print("body after DSL execution-marker lowering:")
    print()

    lowered = algorithm.body.replace("parallel for", "for")

    print(lowered)
    print()
PY

    # =========================================================================
    section "STEP 8 — GENERATED SPECIALIZATION SYMBOLS"

    python3 <<'PY'
import os
from pathlib import Path

from parser import parse
from validator import validate
from ir import _assignments, _specialization_symbol

op = validate(parse(Path(os.environ["OP_FILE"])))

for index, assignment in enumerate(_assignments(op)):
    output_dtype = assignment[op.outputs[0].type_key]

    if op.inputs:
        input_dtype = assignment[op.inputs[0].type_key]
    else:
        input_dtype = output_dtype

    symbol = _specialization_symbol(op, output_dtype, input_dtype)

    print(f"SPECIALIZATION {index}")
    print(f"  assignment   : {assignment}")
    print(f"  output dtype : {output_dtype}")
    print(f"  input dtype  : {input_dtype}")
    print(f"  symbol       : {symbol}")
    print()
PY

    # =========================================================================
    section "STEP 9 — GENERATED C TRANSLATION UNIT"

    python3 <<'PY'
import os
from pathlib import Path

from parser import parse
from validator import validate
from ir import (
    _assignments,
    _bindings,
    _condition_bindings,
    _helper,
    _parameter_bytes,
    _point_selection,
    _selection,
    _specialization_symbol,
)

op = validate(parse(Path(os.environ["OP_FILE"])))

functions = []

for assignment in _assignments(op):
    output_dtype = assignment[op.outputs[0].type_key]

    if op.inputs:
        input_dtype = assignment[op.inputs[0].type_key]
    else:
        input_dtype = output_dtype

    symbol = _specialization_symbol(op, output_dtype, input_dtype)

    declarations, dimensions = _bindings(op, assignment)

    # For visualization we deliberately include every algorithm in the .op
    # instead of selecting a backend/device subset.
    algorithms = list(op.ast.algorithms)

    helpers = "\n".join(
        _helper(
            op,
            assignment,
            algorithm,
            declarations,
            f"{symbol}_{algorithm.name}",
        )
        for algorithm in algorithms
    )

    calls = _selection(op, algorithms, symbol)

    point_dispatch = (
        _point_selection(op, algorithms, symbol)
        if op.ast.hints.pointwise
        else ""
    )

    dims = ", ".join(dimensions) or "0"

    inputs = (
        ", ".join(
            f"input_tensors[{i}]->data->ptr"
            for i in range(len(op.inputs))
        )
        or "NULL"
    )

    condition_bindings = _condition_bindings(op)
    parameter_bytes = _parameter_bytes(op)

    function = f"""{helpers}
boolean {symbol}(
    tensor *output, const tensor *const *input_tensors, extent input_count,
    const void *parameters, extent parameter_bytes) {{
  if (input_count != {len(op.inputs)} ||
      parameter_bytes != {parameter_bytes} ||
      ({parameter_bytes} && !parameters)) return true;

  void *outputs[] = {{ output->data->ptr }};
  const void *inputs[] = {{ {inputs} }};
  extent dimensions[] = {{ {dims} }};

{chr(10).join(condition_bindings)}

{calls}
}}
{point_dispatch}
"""

    functions.append(function)

source = (
    '#include "tensor_core.h"\n'
    '#include "dtype.h"\n'
    '#include "device.h"\n'
    '\n'
    + "\n".join(functions)
)

generated_path = Path(os.environ["GENERATED_C"])
generated_path.write_text(source, encoding="utf-8")

print(source)
PY

    # =========================================================================
    section "STEP 10 — CLANG COMMAND"

    INCLUDE_DIR="$(realpath "$PARSER_DIR/../../include")"

    echo "clang-18 \\"
    echo "  -std=c11 \\"
    echo "  -O1 \\"
    echo "  -emit-llvm \\"
    echo "  -c \\"
    echo "  -I \"$INCLUDE_DIR\" \\"
    echo "  \"$GENERATED_C\" \\"
    echo "  -o \"$BITCODE\""

    echo
    echo "running..."
    echo

    clang-18 \
        -std=c11 \
        -O1 \
        -emit-llvm \
        -c \
        -I "$INCLUDE_DIR" \
        "$GENERATED_C" \
        -o "$BITCODE"

    echo
    echo "clang completed successfully"
    echo

    ls -lh "$BITCODE"

    # =========================================================================
    section "STEP 11 — LLVM BITCODE INFORMATION"

    file "$BITCODE"

    echo
    echo "first 64 bytes:"
    echo

    if command -v xxd >/dev/null 2>&1; then
        xxd -l 64 "$BITCODE"
    else
        od -Ax -tx1 -N64 "$BITCODE"
    fi

    # =========================================================================
    section "STEP 12 — TEXTUAL LLVM IR"

    if command -v llvm-dis-18 >/dev/null 2>&1; then

        llvm-dis-18 \
            "$BITCODE" \
            -o "$LLVM_IR"

    elif command -v llvm-dis >/dev/null 2>&1; then

        llvm-dis \
            "$BITCODE" \
            -o "$LLVM_IR"

    else

        clang-18 \
            -std=c11 \
            -O1 \
            -S \
            -emit-llvm \
            -I "$INCLUDE_DIR" \
            "$GENERATED_C" \
            -o "$LLVM_IR"
    fi

    cat "$LLVM_IR"

    # =========================================================================
    section "STEP 13 — LLVM SYMBOL TABLE"

    if command -v llvm-nm-18 >/dev/null 2>&1; then

        llvm-nm-18 "$BITCODE"

    elif command -v llvm-nm >/dev/null 2>&1; then

        llvm-nm "$BITCODE"

    else

        echo "llvm-nm not available; skipping symbol table"

    fi

    # =========================================================================
    section "STEP 14 — REGISTRY RECORDS"

    python3 <<'PY'
import os
from pathlib import Path

from parser import parse
from validator import validate
from ir import _assignments, _specialization_symbol, ENUM

op = validate(parse(Path(os.environ["OP_FILE"])))

records = []

for assignment in _assignments(op):
    output_dtype = assignment[op.outputs[0].type_key]

    if op.inputs:
        input_dtype = assignment[op.inputs[0].type_key]
    else:
        input_dtype = output_dtype

    symbol = _specialization_symbol(op, output_dtype, input_dtype)

    records.append(
        (
            op,
            ENUM[output_dtype],
            ENUM[input_dtype],
            symbol,
        )
    )

print(f"record count: {len(records)}")
print()

for index, record in enumerate(records):
    operation, output_dtype, input_dtype, symbol = record

    print(f"RECORD {index}")
    print(f"  operation name : {operation.ast.name}")
    print(f"  operation id   : 0x{operation.ast.id:08x}")
    print(f"  output enum    : {output_dtype}")
    print(f"  input enum     : {input_dtype}")
    print(f"  LLVM symbol    : {symbol}")
    print()
PY

    # =========================================================================
    section "STEP 15 — GENERATED registry.c"

    python3 <<'PY'
import os
from pathlib import Path

from parser import parse
from validator import validate
from ir import _assignments, _specialization_symbol, ENUM
from registry import emit_registry

op = validate(parse(Path(os.environ["OP_FILE"])))

bitcode = Path(os.environ["BITCODE"])
registry_path = Path(os.environ["REGISTRY"])

records = []

for assignment in _assignments(op):
    output_dtype = assignment[op.outputs[0].type_key]

    if op.inputs:
        input_dtype = assignment[op.inputs[0].type_key]
    else:
        input_dtype = output_dtype

    symbol = _specialization_symbol(op, output_dtype, input_dtype)

    records.append(
        (
            op,
            ENUM[output_dtype],
            ENUM[input_dtype],
            symbol,
        )
    )

emit_registry(
    bitcode,
    records,
    registry_path,
)

print(
    registry_path.read_text(
        encoding="utf-8"
    )
)
PY

    # =========================================================================
    section "STEP 16 — PIPELINE SUMMARY"

    echo "SOURCE"
    echo
    echo "    $(basename "$OP_FILE")"
    echo "         |"
    echo "         v"
    echo
    echo "LEXER"
    echo
    echo "    lexer.lex()"
    echo "         |"
    echo "         +--> Line"
    echo "         +--> AlgorithmBlock"
    echo "         |"
    echo "         v"
    echo
    echo "PARSER"
    echo
    echo "    parser.parse()"
    echo "         |"
    echo "         v"
    echo
    echo "    Operation AST"
    echo "         |"
    echo "         +--> TypeDef"
    echo "         +--> DeviceDef"
    echo "         +--> DimensionDef"
    echo "         +--> ShapeDef"
    echo "         +--> ValueDecl"
    echo "         +--> Algorithm"
    echo "         +--> Hints"
    echo "         |"
    echo "         v"
    echo
    echo "VALIDATOR"
    echo
    echo "    validator.validate()"
    echo "         |"
    echo "         v"
    echo
    echo "    ValidatedOperation"
    echo "         |"
    echo "         +--> resolved dtype sets"
    echo "         +--> resolved shapes"
    echo "         +--> resolved values"
    echo "         +--> validated algorithms"
    echo "         |"
    echo "         v"
    echo
    echo "SPECIALIZATION"
    echo
    echo "    ir._assignments()"
    echo "         |"
    echo "         v"
    echo
    echo "    one concrete function family"
    echo "    per dtype assignment"
    echo "         |"
    echo "         v"
    echo
    echo "C LOWERING"
    echo
    echo "    generated bindings"
    echo "    generated helpers"
    echo "    generated dispatch"
    echo "    generated pointwise loops"
    echo "         |"
    echo "         v"
    echo
    echo "    operations.c"
    echo "         |"
    echo "         v"
    echo
    echo "CLANG"
    echo
    echo "    clang-18 -emit-llvm"
    echo "         |"
    echo "         v"
    echo
    echo "    operations.bc"
    echo "         |"
    echo "         +------------------+"
    echo "         |                  |"
    echo "         v                  v"
    echo
    echo "    textual LLVM IR     registry.py"
    echo "                            |"
    echo "                            v"
    echo
    echo "                        registry.c"

    divider

} >"$OUTPUT" 2>&1

echo "wrote:"
echo
echo "  $OUTPUT"
echo
echo "view with:"
echo
echo "  less '$OUTPUT'"
