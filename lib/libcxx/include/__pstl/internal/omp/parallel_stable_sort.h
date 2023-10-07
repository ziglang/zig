// -*- C++ -*-
// -*-===----------------------------------------------------------------------===//
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_INTERNAL_OMP_PARALLEL_STABLE_SORT_H
#define _PSTL_INTERNAL_OMP_PARALLEL_STABLE_SORT_H

#include "util.h"
#include "parallel_merge.h"

namespace __pstl
{
namespace __omp_backend
{

namespace __sort_details
{
struct __move_value
{
    template <typename _Iterator, typename _OutputIterator>
    void
    operator()(_Iterator __x, _OutputIterator __z) const
    {
        *__z = std::move(*__x);
    }
};

template <typename _RandomAccessIterator, typename _OutputIterator>
_OutputIterator
__parallel_move_range(_RandomAccessIterator __first1, _RandomAccessIterator __last1, _OutputIterator __d_first)
{
    std::size_t __size = __last1 - __first1;

    // Perform serial moving of small chunks

    if (__size <= __default_chunk_size)
    {
        return std::move(__first1, __last1, __d_first);
    }

    // Perform parallel moving of larger chunks
    auto __policy = __pstl::__omp_backend::__chunk_partitioner(__first1, __last1);

    _PSTL_PRAGMA(omp taskloop)
    for (std::size_t __chunk = 0; __chunk < __policy.__n_chunks; ++__chunk)
    {
        __pstl::__omp_backend::__process_chunk(__policy, __first1, __chunk,
                                       [&](auto __chunk_first, auto __chunk_last)
                                       {
                                           auto __chunk_offset = __chunk_first - __first1;
                                           auto __output_it = __d_first + __chunk_offset;
                                           std::move(__chunk_first, __chunk_last, __output_it);
                                       });
    }

    return __d_first + __size;
}

struct __move_range
{
    template <typename _RandomAccessIterator, typename _OutputIterator>
    _OutputIterator
    operator()(_RandomAccessIterator __first1, _RandomAccessIterator __last1, _OutputIterator __d_first) const
    {
        return __pstl::__omp_backend::__sort_details::__parallel_move_range(__first1, __last1, __d_first);
    }
};
} // namespace __sort_details

template <typename _RandomAccessIterator, typename _Compare, typename _LeafSort>
void
__parallel_stable_sort_body(_RandomAccessIterator __xs, _RandomAccessIterator __xe, _Compare __comp,
                            _LeafSort __leaf_sort)
{
    using _ValueType = typename std::iterator_traits<_RandomAccessIterator>::value_type;
    using _VecType = typename std::vector<_ValueType>;
    using _OutputIterator = typename _VecType::iterator;
    using _MoveValue = typename __omp_backend::__sort_details::__move_value;
    using _MoveRange = __omp_backend::__sort_details::__move_range;

    if (__should_run_serial(__xs, __xe))
    {
        __leaf_sort(__xs, __xe, __comp);
    }
    else
    {
        std::size_t __size = __xe - __xs;
        auto __mid = __xs + (__size / 2);
        __pstl::__omp_backend::__parallel_invoke_body(
            [&]() { __parallel_stable_sort_body(__xs, __mid, __comp, __leaf_sort); },
            [&]() { __parallel_stable_sort_body(__mid, __xe, __comp, __leaf_sort); });

        // Perform a parallel merge of the sorted ranges into __output_data.
        _VecType __output_data(__size);
        _MoveValue __move_value;
        _MoveRange __move_range;
        __utils::__serial_move_merge __merge(__size);
        __pstl::__omp_backend::__parallel_merge_body(
            __mid - __xs, __xe - __mid, __xs, __mid, __mid, __xe, __output_data.begin(), __comp,
            [&__merge, &__move_value, &__move_range](_RandomAccessIterator __as, _RandomAccessIterator __ae,
                                                     _RandomAccessIterator __bs, _RandomAccessIterator __be,
                                                     _OutputIterator __cs, _Compare __comp)
            { __merge(__as, __ae, __bs, __be, __cs, __comp, __move_value, __move_value, __move_range, __move_range); });

        // Move the values from __output_data back in the original source range.
        __pstl::__omp_backend::__sort_details::__parallel_move_range(__output_data.begin(), __output_data.end(), __xs);
    }
}

template <class _ExecutionPolicy, typename _RandomAccessIterator, typename _Compare, typename _LeafSort>
void
__parallel_stable_sort(__pstl::__internal::__openmp_backend_tag __tag, _ExecutionPolicy&& /*__exec*/,
                       _RandomAccessIterator __xs, _RandomAccessIterator __xe, _Compare __comp, _LeafSort __leaf_sort,
                       std::size_t __nsort = 0)
{
    auto __count = static_cast<std::size_t>(__xe - __xs);
    if (__count <= __default_chunk_size || __nsort < __count)
    {
        __leaf_sort(__xs, __xe, __comp);
        return;
    }

    // TODO: the partial sort implementation should
    // be shared with the other backends.

    if (omp_in_parallel())
    {
        if (__count <= __nsort)
        {
            __pstl::__omp_backend::__parallel_stable_sort_body(__xs, __xe, __comp, __leaf_sort);
        }
        else
        {
            __pstl::__omp_backend::__parallel_stable_partial_sort(__tag, __xs, __xe, __comp, __leaf_sort, __nsort);
        }
    }
    else
    {
        _PSTL_PRAGMA(omp parallel)
        _PSTL_PRAGMA(omp single nowait)
        if (__count <= __nsort)
        {
            __pstl::__omp_backend::__parallel_stable_sort_body(__xs, __xe, __comp, __leaf_sort);
        }
        else
        {
            __pstl::__omp_backend::__parallel_stable_partial_sort(__tag, __xs, __xe, __comp, __leaf_sort, __nsort);
        }
    }
}

} // namespace __omp_backend
} // namespace __pstl
#endif // _PSTL_INTERNAL_OMP_PARALLEL_STABLE_SORT_H
