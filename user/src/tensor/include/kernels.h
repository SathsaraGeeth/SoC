/*
 * Comments:
 * 1. Declare enum and function prototypes by parsing operations.def file.
 *    e.g.
 *      enum tensor_operation {
 *          ADD = 10,
 *          MUL = 20,
 *      };
 *
 *      boolean add_lower(
 *          tensor *output,
 *          const tensor *const *inputs,
 *          extent input_count,
 *          const void *parameters,
 *          extent parameter_bytes
 *      );
 *
 *      boolean mul_lower(
 *          tensor *output,
 *          const tensor *const *inputs,
 *          extent input_count,
 *          const void *parameters,
 *          extent parameter_bytes
 *      );
 * 2. FROZEN
 */

#ifndef TENSOR_KERNELS_H
#define TENSOR_KERNELS_H

#include "tensor_core.h"

#define TENSOR_OPERATION(op, code, ker, lower, input_arity, parameter_size) op = code,
enum tensor_operation {
#include "../src/kernels/operations.def"
};
#undef TENSOR_OPERATION

#define TENSOR_OPERATION(op, code, ker, lower, input_arity, parameter_size) \
    boolean lower(tensor *output, const tensor *const *inputs,              \
                  extent input_count, const void *parameters,               \
                  extent parameter_bytes);
#include "../src/kernels/operations.def"
#undef TENSOR_OPERATION

#endif
