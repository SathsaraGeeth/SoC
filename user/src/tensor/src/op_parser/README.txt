Tensor operation language proposal
==================================

Status
------

This document specifies the `.op` language accepted by the modular operation
compiler in this directory.

The language is intentionally strict.  A file has four sections, in this
order:

    define
    declare
    code
    hints

The `define` and `declare` sections are DSL syntax.  They describe the
operation and the names that the generator must make available to C.
Each named algorithm inside `code` has a C11 body.  Selection and execution
metadata do not appear in the code section; they belong in `hints`.


1. Lexical rules
----------------

1. Files use UTF-8 and the `.op` extension.
2. Keywords are lowercase and case-sensitive.
3. Identifiers match `[A-Za-z_][A-Za-z0-9_]*`.
4. Decimal and hexadecimal integer literals use C syntax.  Negative values
   are not permitted for IDs, dimensions, ranks, or array sizes.
5. Whitespace is insignificant outside C algorithm bodies.
6. `//` starts a line comment outside C algorithm bodies.
7. A name must be declared before it is used.
8. A name may be declared only once in an `.op` file, regardless of section.
9. Commas separate list items.  A trailing comma is not permitted.
10. Semicolons terminate statements in `define`, `declare`, and `hints`.
11. C preprocessor directives are not permitted.  In particular, `#define`
    is not DSL syntax.  This avoids confusing DSL type sets with C macros.

The reserved words are:

    define declare code begin endcode algorithm endalgorithm hints endhints
    name id type devices dim shape
    in out param pointwise target operations requires prefer when
    true false any generic cpu cuda


2. File grammar
---------------

The following grammar is informative EBNF.  The detailed rules in later
sections are normative.

    file              = define-section,
                        declare-section,
                        code-section,
                        hints-section;

    define-section    = "define", { definition }, "end", "define";
    definition        = type-definition
                      | device-definition
                      | dimension-definition
                      | shape-definition;

    type-definition   = "type", identifier, "=",
                        ( dtype | "any" | "{", dtype-list, "}" ), ";";
    device-definition = "devices", identifier, "=",
                        "{", device-list, "}", ";";
    dimension-definition
                      = "dim", identifier, [ "=", integer ], ";";
    shape-definition  = "shape", identifier, "=",
                        "[", shape-list, "]", ";";

    declare-section   = "declare",
                        name-declaration,
                        id-declaration,
                        { value-declaration },
                        "end", "declare";
    name-declaration  = "name", identifier, ";";
    id-declaration    = "id", integer, ";";
    value-declaration = ( "in" | "out" ), identifier, ":",
                        type-reference, shape-reference, ";"
                      | "param", identifier, ":",
                        concrete-dtype, [ "[", positive-integer, "]" ], ";";

    code-section      = "code", "begin",
                        algorithm, { algorithm },
                        "endcode";
    algorithm         = "algorithm", identifier, "begin",
                        c-block-items,
                        "endalgorithm", ":", identifier;

    hints-section     = "hints", "begin",
                        pointwise-hint,
                        { target-hint | operations-hint
                        | requirement-hint | preference-hint },
                        "endhints";
    pointwise-hint    = "pointwise", ":", boolean, ";";
    target-hint       = "target", identifier, ":", device-reference, ";";
    operations-hint   = "operations", identifier, ":",
                        integer-expression, ";";
    requirement-hint  = "requires", identifier, ":", c-expression, ";";
    preference-hint   = "prefer", identifier,
                        [ "when", c-expression ], ";";

`c-block-items` and `c-expression` are defined by C11, with the additional
name restrictions described below.  In `endalgorithm: NAME`, `NAME` must
exactly match the name after the corresponding `algorithm` keyword.

`integer-expression` is a side-effect-free C integer expression containing
only integer literals, declared dimension names, `point_count`, and the
`NAME_size` or `NAME_rank` facts of declared tensor values.


3. Define section
-----------------

The define section creates aliases and shape symbols for use by declarations
and algorithms.  These are DSL definitions, not textual substitutions.

Example:

    define
      type image_type = {real32, uint8, int32};
      type weight_type = real32;
      type result_type = int8;
      type any_type = any;

      devices host_devices = {generic, cpu};
      devices all_devices = {generic, cpu, cuda};

      dim C = 3;
      dim H;
      dim W;
      shape image_shape = [C, H, W];
    end define


3.1 Data types
~~~~~~~~~~~~~~

The concrete dtypes are:

    int8 int16 int32 int64
    uint8 uint16 uint32 uint64
    real32 real64

Their meaning, limits, and corresponding C typedefs come from `dtype.h`.
No other concrete dtype name is valid.

A type definition has exactly one of these forms:

    type scalar = real32;
    type numeric = {real32, uint8, int32};
    type unrestricted = any;

`any` means the set of all concrete dtypes listed above.  It does not mean an
unknown C type and cannot be used as a parameter type.

A brace-enclosed type set must contain at least one concrete dtype.  Duplicate
members are an error.  A type definition may be used only as the type of an
`in` or `out` declaration.

When an input and an output use the same type definition, they must select the
same concrete dtype for one compiled variant.  Different type definitions are
independent, even if their member lists happen to be equal.


3.2 Devices
~~~~~~~~~~~

The device names are:

    generic cpu cuda

Their meaning comes from `device.h`.

A device definition is a set:

    devices cpu_targets = {generic, cpu};
    devices disabled = {};

An empty set is useful for keeping a drafted or reference algorithm in the
operation without compiling it for a backend.  Duplicate members are an
error.  `generic` means the portable generic backend; it does not implicitly
include `cpu` or `cuda`.


3.3 Dimensions and shapes
~~~~~~~~~~~~~~~~~~~~~~~~~

A dynamic dimension has no assigned value:

    dim H;

A fixed dimension has a positive integer value:

    dim C = 3;

Zero-sized fixed dimensions are not permitted.  Runtime tensors may still
have a zero extent if the tensor API supports them; that policy is outside
this language.

A named shape is a non-empty list of dimensions or positive integer literals:

    shape image = [C, H, W];
    shape kernel = [C, 3, 3];

`*` means one anonymous dynamic dimension:

    shape row = [*, W];

Each `*` is independent.  It creates no C variable, so an algorithm cannot
refer to its value by name.

`**` means a tensor of arbitrary rank:

    shape flat = [**];

`**` must be the only item in a shape.  It exposes only the tensor's flat
element count, not individual dimensions.  Use named dimensions when an
algorithm needs rank or extent values.

An inline shape and a named shape have identical meaning:

    in x: image_type [C, H, W];
    in x: image_type image;


4. Declare section
------------------

The declare section gives the operation its identity and declares all values
visible to algorithms.

Example:

    declare
      name conv2d;
      id 0x00010001;

      in x: image_type image_shape;
      in weights: weight_type [C, 3, 3];
      in mask: any_type [*, 3, W];
      in coefficients: any_type [**];
      out y: result_type [C, H, W];

      param amount: real32;
      param stride: int32;
    end declare


4.1 Name and ID
~~~~~~~~~~~~~~~

Exactly one `name` and one `id` are required, in that order and before value
declarations.

The operation name must be unique across the complete set of `.op` files.
The ID may be decimal or hexadecimal, must be unique, and must fit in 28 bits:

    0 <= id <= 0x0fffffff


4.2 Inputs and outputs
~~~~~~~~~~~~~~~~~~~~~~

At least one output is required.  Inputs are optional.

Every input and output declaration has:

1. a unique value name;
2. a concrete dtype or a type definition; and
3. an inline or named shape.

The same named dimension used by multiple declarations is a shape constraint.
At dispatch time all occurrences must have the same extent.  For example,
`H` in `[C, H, W]` refers to one value everywhere in the file.

A fixed dimension is also a constraint.  `[C, H, W]` with `dim C = 3;`
requires the corresponding extent to equal 3.


4.3 Parameters
~~~~~~~~~~~~~~

Parameters are scalar values and must use a concrete dtype:

    param amount: real32;

Fixed-size parameter arrays are also permitted:

    param permutation: uint64 [8];

The array length must be a positive integer literal.  Dynamic parameter
arrays are not permitted.  Type definitions, `any`, and tensor shapes are not
permitted on parameters.
Parameters are packed in declaration order using the natural size and
alignment of their dtype from `dtype.h`.  The generator must insert padding
when required and must validate the supplied parameter-block size.


5. Names available to C algorithms
----------------------------------

The generator creates C code around each algorithm body and includes
`tensor_core.h`, `dtype.h`, and `device.h`.  The exact bindings depend on the
operation's `pointwise` hint.

For `pointwise: false`, the following bindings are available:

* An input named `x` is `const T_x *restrict x`.
* An output named `y` is `T_y *restrict y`.
* A parameter named `stride` is a scalar variable with its declared C type.
* A named dynamic or fixed dimension such as `H` is available as `extent H`.
* A tensor using `[**]` exposes `<name>_size` as an `extent`.
* Every tensor exposes `<name>_rank` as an `extent`.
* Every tensor exposes `<name>_shape` as `const extent *`.

For `pointwise: true`, the generator loops over the flat element count of the
first output:

* All outputs must have the same shape and are scalar lvalues in the body.
* An input with that same shape is a scalar value in the body.
* An input with a different shape remains a read-only pointer.
* `point_index` is the current zero-based flat index.
* `point_count` is the total number of output elements.
* Parameters, dimensions, ranks, shapes, and `[**]` sizes remain available.

For example, with `in x: pixel [**]; out y: pixel [**];`, a pointwise
algorithm reads scalar `x` and assigns scalar `y`; it does not write `y[i]`.
An input such as a lookup table with shape `[K]` remains a pointer and may be
indexed normally.

`T_x` and `T_y` above denote generator-selected concrete C typedefs, not
literal identifiers promised to the algorithm.  The algorithm uses `x` and
`y` normally; it should use explicit project types such as `real32` for local
variables when a type name is needed.

Inputs are read-only.  Writing through an input pointer, casting away `const`,
or retaining any generated pointer after the algorithm returns is invalid.

The operation declarations are the only way to introduce tensor and parameter
bindings.  Algorithms must not redeclare those names.


6. Code section
---------------

The code section has exactly these outer delimiters:

    code begin
      algorithm direct begin
        for (extent c = 0; c < C; ++c) {
          /* Valid C11 statements. */
        }
        return false;
      endalgorithm: direct
    endcode

`code begin` and `endcode` each occur exactly once.  At least one algorithm is
required.  Algorithm names must be unique within the file.

Everything after `algorithm NAME begin` and before its matching
`endalgorithm: NAME` is parsed as C11 block items.  It must be valid C after
the generated bindings described above are placed in scope.  The closing name
is mandatory, which prevents a missing or misplaced terminator from silently
ending the wrong algorithm.

The terminator is recognized only as a DSL line outside C comments, string
literals, and character literals.  It must appear by itself except for
whitespace:

    endalgorithm: direct

Device names, `requires` expressions, preferences, and `pointwise` do not
appear in an algorithm header.  They are declared only in `hints`.

Each body returns a `boolean`:

    false   success
    true    failure

Falling off the end of an algorithm is an error.  The body must return a
value on every reachable path.

An algorithm may use declarations from this `.op` file and public names from
the included project headers.  It may not:

* contain preprocessor directives;
* define another function;
* use file-scope declarations;
* use compiler-specific extensions unless the language version later lists
  them explicitly; or
* refer to declarations from another `.op` file.


7. Hints section
----------------

The hints section contains execution classification and algorithm-selection
metadata.  It contains no algorithm C code.

Example:

    hints begin
      pointwise: false;
      target winograd: host;
      requires winograd: stride == 1 && H >= 4 && W >= 4;
      target direct: portable;
      prefer winograd when H >= 16 && W >= 16;
      prefer direct;
    endhints


7.1 Pointwise classification
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Exactly one pointwise hint is required and it must be the first hint:

    pointwise: true;

or:

    pointwise: false;

This applies to the complete operation, not to one algorithm.  All algorithms
in the file therefore receive the same kind of generated bindings.  Marking
an operation as pointwise is a promise that every output element can be
computed independently under the rules in section 5.


7.2 Device targets
~~~~~~~~~~~~~~~~~~

A target hint assigns a device or device set to an algorithm:

    target direct: generic;
    target winograd: host;

Every algorithm must have exactly one target hint.  A target must name an
algorithm declared in the code section.  An algorithm is a candidate only
when the active device belongs to its target set.


7.3 Operation counts
~~~~~~~~~~~~~~~~~~~~

Every algorithm must have exactly one operation-count hint:

    operations direct: 2 * M * N * K;

The expression is the number of scalar arithmetic operations performed by
one complete invocation of that algorithm.  Count integer and floating-point
addition, subtraction, multiplication, division, remainder, and shifts as
one operation each.  Count fused multiply-add as two operations.  Do not
count loads, stores, address calculation, casts, comparisons, branches, or
loop-control operations.  An algorithm that only copies or aliases data uses
zero.

The expression may contain integer literals, declared dimensions,
`point_count`, and the `_size` or `_rank` fact of a declared tensor.  It must
not contain parameters, calls, assignments, side effects, or data-dependent
terms.  The result is evaluated as `uint64`.  Overflow is an error at runtime
and must not be used to represent an unknown count.

The count belongs to an algorithm because different algorithms for one
operation can have different costs.  Runtime profiling evaluates the count
for the same algorithm selected by `requires` and `prefer`.


7.4 Requirements
~~~~~~~~~~~~~~~~

An algorithm may have at most one requirement:

    requires winograd: stride == 1 && H >= 4 && W >= 4;

The text after `:` and before the terminating `;` is a C11 scalar expression.
It may use parameters, named dimensions, `<name>_rank`, `<name>_shape`,
`<name>_size`, `point_count`, and public constants from the included headers.
It must not have side effects.  Function calls, assignments, increments,
decrements, and comma operators are forbidden.

An algorithm without a `requires` hint has the requirement `true`.


7.5 Preferences
~~~~~~~~~~~~~~~

A preferred name must refer to an algorithm in the same file.  A `when`
expression follows the same rules as a `requires` expression.

Preference hints are tested in source order.  The first matching preference
whose algorithm is still an applicable candidate wins.  A preference naming
an inapplicable algorithm is skipped.

All algorithms in one operation must be semantically interchangeable for
inputs satisfying their requirements.


7.6 Complete and deterministic selection
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For every supported device and valid dtype combination, at least one
unconditional algorithm must target that device.  This guarantees a fallback
regardless of runtime dimensions and parameters.

Selection proceeds as follows:

1. Remove algorithms whose target does not include the active device.
2. Remove algorithms whose `requires` expression evaluates to false.
3. Apply `prefer` hints in source order.
4. If no preference selects an algorithm, choose the first remaining
   algorithm in code-section order.
5. If no algorithm remains, dispatch fails without executing an algorithm.

Code-section order is therefore a defined fallback order, not an
implementation accident.


8. Complete example
-------------------

    define
      type pixel = {real32, uint8, int32};
      type weights = real32;
      type result = int8;
      devices portable = {generic, cpu, cuda};
      devices host = {generic, cpu};
      dim C = 3;
      dim H;
      dim W;
      shape image = [C, H, W];
    end define

    declare
      name conv2d;
      id 0x00010001;
      in x: pixel image;
      in kernel: weights [C, 3, 3];
      out y: result image;
      param stride: int32;
    end declare

    code begin
      algorithm winograd begin
        /* Valid C11 implementation using x, kernel, y, C, H, W, and stride. */
        return false;
      endalgorithm: winograd

      algorithm direct begin
        for (extent c = 0; c < C; ++c) {
          for (extent h = 0; h < H; ++h) {
            for (extent w = 0; w < W; ++w) {
              /* Direct convolution implementation. */
            }
          }
        }
        return false;
      endalgorithm: direct
    endcode

    hints begin
      pointwise: false;
      target winograd: host;
      operations winograd: 12 * C * H * W;
      requires winograd: stride == 1 && H >= 4 && W >= 4;
      target direct: portable;
      operations direct: 18 * C * H * W;
      prefer winograd when H * W >= 256;
      prefer direct;
    endhints


9. Validation summary
---------------------

A conforming parser must reject a file when:

* its sections are missing, duplicated, or out of order;
* a token does not match the lexical rules;
* a name or ID is duplicated;
* an undefined name is referenced;
* a dtype, device, shape, or parameter declaration violates its section;
* a shared or fixed dimension constraint cannot be satisfied;
* a code or condition is not valid under the restricted C11 rules;
* an algorithm can finish without returning a boolean;
* an `endalgorithm` name does not match its opening algorithm name;
* the required pointwise, target, or operations hints are missing or
  duplicated;
* no algorithm covers a supported device and dtype combination; or
* deterministic selection cannot be performed using the rules above.

The compiler implementation is required to conform to these syntax and
semantic rules.


10. Compiler pipeline and artifact
----------------------------------

The implementation follows this pipeline:

    .op source
        |
        v
      lexer
        |
        v
      parser
        |
        v
       AST
        |
        v
      semantic validator
        |
        v
      validated operation IR
        |
        v
      operations.bc

The compiler processes the complete operation tree as one compilation unit.
It emits exactly one LLVM bitcode file, `operations.bc`, for the selected
device backend.  Every accepted operation, dtype specialization, algorithm,
requirement, and dynamic-selection wrapper is encoded in that module.

The accompanying generated registry is host integration metadata, not another
IR module.  It embeds the same `operations.bc` byte sequence once and maps an
operation ID and dtype signature to a symbol within the module.  It must not
contain duplicated per-operation bitcode arrays.
