// -*- C++ -*-
// -*-===----------------------------------------------------------------------===//
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_INTERNAL_OMP_PARALLEL_TRANSFORM_REDUCE_H
#define _PSTL_INTERNAL_OMP_PARALLEL_TRANSFORM_REDUCE_H

#include "util.h"

namespace __pstl
{
namespace __omp_backend
{

//------------------------------------------------------------------------
// parallel_transform_reduce
//
// Notation:
//      r(i,j,init) returns reduction of init with reduction over [i,j)
//      u(i) returns f(i,i+1,identity) for a hypothetical left identity element
//      of r c(x,y) combines values x and y that were the result of r or u
//------------------------------------------------------------------------

template <class _RandomAccessIterator, class _UnaryOp, class _Value, class _Combiner, class _Reduction>
auto
__transform_reduce_body(_RandomAccessIterator __first, _RandomAccessIterator __last, _UnaryOp __unary_op, _Value __init,
                        _Combiner __combiner, _Reduction __reduction)
{
    const std::size_t __num_threads = omp_get_num_threads();
    const std::size_t __size = __last - __first;

    // Initial partition of the iteration space into chunks. If the range is too small,
    // this will result in a nonsense policy, so we check on the size as well below.
    auto __policy = __omp_backend::__chunk_partitioner(__first + __num_threads, __last);

    if (__size <= __num_threads || __policy.__n_chunks < 2)
    {
        return __reduction(__first, __last, __init);
    }

    // Here, we cannot use OpenMP UDR because we must store the init value in
    // the combiner and it will be used several times. Although there should be
    // the only one; we manually generate the identity elements for each thread.
    std::vector<_Value> __accums;
    __accums.reserve(__num_threads);

    // initialize accumulators for all threads
    for (std::size_t __i = 0; __i < __num_threads; ++__i)
    {
        __accums.emplace_back(__unary_op(__first + __i));
    }

    // main loop
    _PSTL_PRAGMA(omp taskloop shared(__accums))
    for (std::size_t __chunk = 0; __chunk < __policy.__n_chunks; ++__chunk)
    {
        __pstl::__omp_backend::__process_chunk(__policy, __first + __num_threads, __chunk,
                                       [&](auto __chunk_first, auto __chunk_last)
                                       {
                                           auto __thread_num = omp_get_thread_num();
                                           __accums[__thread_num] =
                                               __reduction(__chunk_first, __chunk_last, __accums[__thread_num]);
                                       });
    }

    // combine by accumulators
    for (std::size_t __i = 0; __i < __num_threads; ++__i)
    {
        __init = __combiner(__init, __accums[__i]);
    }

    return __init;
}

template <class _ExecutionPolicy, class _RandomAccessIterator, class _UnaryOp, class _Value, class _Combiner,
          class _Reduction>
_Value
__parallel_transform_reduce(__pstl::__internal::__openmp_backend_tag, _ExecutionPolicy&&, _RandomAccessIterator __first,
                            _RandomAccessIterator __last, _UnaryOp __unary_op, _Value __init, _Combiner __combiner,
                            _Reduction __reduction)
{
    _Value __result = __init;
    if (omp_in_parallel())
    {
        // We don't create a nested parallel region in an existing parallel
        // region: just create tasks
        __result = __pstl::__omp_backend::__transform_reduce_body(__first, __last, __unary_op, __init, __combiner,
                                                                  __reduction);
    }
    else
    {
        // Create a parallel region, and a single thread will create tasks
        // for the region.
        _PSTL_PRAGMA(omp parallel)
        _PSTL_PRAGMA(omp single nowait)
        {
            __result = __pstl::__omp_backend::__transform_reduce_body(__first, __last, __unary_op, __init, __combiner,
                                                                      __reduction);
        }
    }

    return __result;
}

} // namespace __omp_backend
} // namespace __pstl
#endif // _PSTL_INTERNAL_OMP_PARALLEL_TRANSFORM_REDUCE_H
