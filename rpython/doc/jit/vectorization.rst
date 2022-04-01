
Vectorization
=============

To find parallel instructions the tracer must provide enough information about
memory load/store operations. They must be adjacent in memory. The requirement for
that is that they use the same index variable and offset can be expressed as a
a linear or affine combination.

Command line flags:

* --jit vec=1: turns on the vectorization for marked jitdrivers
  (e.g. those in the NumPyPy module).
* --jit vec_all=1: turns on the vectorization for any jit driver. See parameters for
  the filtering heuristics of traces.

Features
--------

Currently the following operations can be vectorized if the trace contains parallel operations:

* float32/float64: add, substract, multiply, divide, negate, absolute
* int8/int16/int32/int64 arithmetic: add, substract, multiply, negate, absolute
* int8/int16/int32/int64 logical: and, or, xor

Reduction
---------

Reduction is implemented:

* sum, prod, any, all

Constant & Variable Expansion
-----------------------------

Packed arithmetic operations expand scalar variables or contants into vector registers.

Guard Strengthening
-------------------

Unrolled guards are strengthend on an arithmetical level (See GuardStrengthenOpt).
The resulting vector trace will only have one guard that checks the index.

Calculations on the index variable that are redundant (because of the merged
load/store instructions) are not removed. The backend removes these instructions
while assembling the trace.

In addition a simple heuristic (enabled by --jit vec_all=1) tries to remove
array bound checks for application level loops. It tries to identify the array
bound checks and adds a transitive guard at the top of the loop::

    label(...)
    ...
    guard(i < n) # index guard
    ...
    guard(i < len(a))
    a = load(..., i, ...)
    ...
    jump(...)
    # becomes
    guard(n < len(a))
    label(...)
    guard(i < n) # index guard
    ...
    a = load(..., i, ...)
    ...
    jump(...)



Future Work and Limitations
---------------------------

* The only SIMD instruction architecture currently supported is SSE4.1
* Packed mul for int8,int64 (see PMUL_). It would be possible to use PCLMULQDQ. Only supported
  by some CPUs and must be checked in the cpuid.
* Loop that convert types from int(8|16|32|64) to int(8|16) are not supported in
  the current SSE4.1 assembler implementation.
  The opcode needed spans over multiple instructions. In terms of performance
  there might only be little to non advantage to use SIMD instructions for this
  conversions.
* For a guard that checks true/false on a vector integer regsiter, it would be handy
  to have 2 xmm registers (one filled with zero bits and the other with one every bit).
  This cuts down 2 instructions for guard checking, trading for higher register pressure.
* prod, sum are only supported by 64 bit data types
* isomorphic function prevents the following cases for combination into a pair:
  1) getarrayitem_gc, getarrayitem_gc_pure
  2) int_add(v,1), int_sub(v,-1)

.. _PMUL: http://stackoverflow.com/questions/8866973/can-long-integer-routines-benefit-from-sse/8867025#8867025

