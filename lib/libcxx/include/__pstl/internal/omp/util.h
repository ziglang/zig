// -*- C++ -*-
// -*-===----------------------------------------------------------------------===//
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_INTERNAL_OMP_UTIL_H
#define _PSTL_INTERNAL_OMP_UTIL_H

#include <algorithm>
#include <atomic>
#include <iterator>
#include <cstddef>
#include <cstdio>
#include <memory>
#include <vector>
#include <omp.h>

#include "../parallel_backend_utils.h"
#include "../unseq_backend_simd.h"
#include "../utils.h"

// Portability "#pragma" definition
#ifdef _MSC_VER
#    define _PSTL_PRAGMA(x) __pragma(x)
#else
#    define _PSTL_PRAGMA(x) _Pragma(#    x)
#endif

namespace __pstl
{
namespace __omp_backend
{

//------------------------------------------------------------------------
// use to cancel execution
//------------------------------------------------------------------------
inline void
__cancel_execution()
{
    // TODO: Figure out how to make cancelation work.
}

//------------------------------------------------------------------------
// raw buffer
//------------------------------------------------------------------------

template <typename _Tp>
class __buffer
{
    std::allocator<_Tp> __allocator_;
    _Tp* __ptr_;
    const std::size_t __buf_size_;
    __buffer(const __buffer&) = delete;
    void
    operator=(const __buffer&) = delete;

  public:
    __buffer(std::size_t __n) : __allocator_(), __ptr_(__allocator_.allocate(__n)), __buf_size_(__n) {}

    operator bool() const { return __ptr_ != nullptr; }

    _Tp*
    get() const
    {
        return __ptr_;
    }
    ~__buffer() { __allocator_.deallocate(__ptr_, __buf_size_); }
};

// Preliminary size of each chunk: requires further discussion
inline constexpr std::size_t __default_chunk_size = 2048;

// Convenience function to determine when we should run serial.
template <typename _Iterator, std::enable_if_t<!std::is_integral<_Iterator>::value, bool> = true>
constexpr auto
__should_run_serial(_Iterator __first, _Iterator __last) -> bool
{
    using _difference_type = typename std::iterator_traits<_Iterator>::difference_type;
    auto __size = std::distance(__first, __last);
    return __size <= static_cast<_difference_type>(__default_chunk_size);
}

template <typename _Index, std::enable_if_t<std::is_integral<_Index>::value, bool> = true>
constexpr auto
__should_run_serial(_Index __first, _Index __last) -> bool
{
    using _difference_type = _Index;
    auto __size = __last - __first;
    return __size <= static_cast<_difference_type>(__default_chunk_size);
}

struct __chunk_metrics
{
    std::size_t __n_chunks;
    std::size_t __chunk_size;
    std::size_t __first_chunk_size;
};

// The iteration space partitioner according to __requested_chunk_size
template <class _RandomAccessIterator, class _Size = std::size_t>
auto
__chunk_partitioner(_RandomAccessIterator __first, _RandomAccessIterator __last,
                    _Size __requested_chunk_size = __default_chunk_size) -> __chunk_metrics
{
    /*
     * This algorithm improves distribution of elements in chunks by avoiding
     * small tail chunks. The leftover elements that do not fit neatly into
     * the chunk size are redistributed to early chunks. This improves
     * utilization of the processor's prefetch and reduces the number of
     * tasks needed by 1.
     */

    const _Size __n = __last - __first;
    _Size __n_chunks = 0;
    _Size __chunk_size = 0;
    _Size __first_chunk_size = 0;
    if (__n < __requested_chunk_size)
    {
        __chunk_size = __n;
        __first_chunk_size = __n;
        __n_chunks = 1;
        return __chunk_metrics{__n_chunks, __chunk_size, __first_chunk_size};
    }

    __n_chunks = (__n / __requested_chunk_size) + 1;
    __chunk_size = __n / __n_chunks;
    __first_chunk_size = __chunk_size;
    const _Size __n_leftover_items = __n - (__n_chunks * __chunk_size);

    if (__n_leftover_items == __chunk_size)
    {
        __n_chunks += 1;
        return __chunk_metrics{__n_chunks, __chunk_size, __first_chunk_size};
    }
    else if (__n_leftover_items == 0)
    {
        __first_chunk_size = __chunk_size;
        return __chunk_metrics{__n_chunks, __chunk_size, __first_chunk_size};
    }

    const _Size __n_extra_items_per_chunk = __n_leftover_items / __n_chunks;
    const _Size __n_final_leftover_items = __n_leftover_items - (__n_extra_items_per_chunk * __n_chunks);

    __chunk_size += __n_extra_items_per_chunk;
    __first_chunk_size = __chunk_size + __n_final_leftover_items;

    return __chunk_metrics{__n_chunks, __chunk_size, __first_chunk_size};
}

template <typename _Iterator, typename _Index, typename _Func>
void
__process_chunk(const __chunk_metrics& __metrics, _Iterator __base, _Index __chunk_index, _Func __f)
{
    auto __this_chunk_size = __chunk_index == 0 ? __metrics.__first_chunk_size : __metrics.__chunk_size;
    auto __index = __chunk_index == 0 ? 0
                                      : (__chunk_index * __metrics.__chunk_size) +
                                            (__metrics.__first_chunk_size - __metrics.__chunk_size);
    auto __first = __base + __index;
    auto __last = __first + __this_chunk_size;
    __f(__first, __last);
}

} // namespace __omp_backend
} // namespace __pstl

#endif // _PSTL_INTERNAL_OMP_UTIL_H
