// -*- C++ -*-
// -*-===----------------------------------------------------------------------===//
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_INTERNAL_OMP_PARALLEL_SCAN_H
#define _PSTL_INTERNAL_OMP_PARALLEL_SCAN_H

#include "parallel_invoke.h"

namespace __pstl
{
namespace __omp_backend
{

template <typename _Index>
_Index
__split(_Index __m)
{
    _Index __k = 1;
    while (2 * __k < __m)
        __k *= 2;
    return __k;
}

template <typename _Index, typename _Tp, typename _Rp, typename _Cp>
void
__upsweep(_Index __i, _Index __m, _Index __tilesize, _Tp* __r, _Index __lastsize, _Rp __reduce, _Cp __combine)
{
    if (__m == 1)
        __r[0] = __reduce(__i * __tilesize, __lastsize);
    else
    {
        _Index __k = __split(__m);
        __omp_backend::__parallel_invoke_body(
            [=] { __omp_backend::__upsweep(__i, __k, __tilesize, __r, __tilesize, __reduce, __combine); },
            [=] {
                __omp_backend::__upsweep(__i + __k, __m - __k, __tilesize, __r + __k, __lastsize, __reduce, __combine);
            });
        if (__m == 2 * __k)
            __r[__m - 1] = __combine(__r[__k - 1], __r[__m - 1]);
    }
}

template <typename _Index, typename _Tp, typename _Cp, typename _Sp>
void
__downsweep(_Index __i, _Index __m, _Index __tilesize, _Tp* __r, _Index __lastsize, _Tp __initial, _Cp __combine,
            _Sp __scan)
{
    if (__m == 1)
        __scan(__i * __tilesize, __lastsize, __initial);
    else
    {
        const _Index __k = __split(__m);
        __omp_backend::__parallel_invoke_body(
            [=] { __omp_backend::__downsweep(__i, __k, __tilesize, __r, __tilesize, __initial, __combine, __scan); },
            // Assumes that __combine never throws.
            // TODO: Consider adding a requirement for user functors to be constant.
            [=, &__combine]
            {
                __omp_backend::__downsweep(__i + __k, __m - __k, __tilesize, __r + __k, __lastsize,
                                           __combine(__initial, __r[__k - 1]), __combine, __scan);
            });
    }
}

template <typename _ExecutionPolicy, typename _Index, typename _Tp, typename _Rp, typename _Cp, typename _Sp,
          typename _Ap>
void
__parallel_strict_scan_body(_Index __n, _Tp __initial, _Rp __reduce, _Cp __combine, _Sp __scan, _Ap __apex)
{
    _Index __p = omp_get_num_threads();
    const _Index __slack = 4;
    _Index __tilesize = (__n - 1) / (__slack * __p) + 1;
    _Index __m = (__n - 1) / __tilesize;
    __buffer<_Tp> __buf(__m + 1);
    _Tp* __r = __buf.get();

    __omp_backend::__upsweep(_Index(0), _Index(__m + 1), __tilesize, __r, __n - __m * __tilesize, __reduce, __combine);

    std::size_t __k = __m + 1;
    _Tp __t = __r[__k - 1];
    while ((__k &= __k - 1))
    {
        __t = __combine(__r[__k - 1], __t);
    }

    __apex(__combine(__initial, __t));
    __omp_backend::__downsweep(_Index(0), _Index(__m + 1), __tilesize, __r, __n - __m * __tilesize, __initial,
                               __combine, __scan);
}

template <class _ExecutionPolicy, typename _Index, typename _Tp, typename _Rp, typename _Cp, typename _Sp, typename _Ap>
void
__parallel_strict_scan(__pstl::__internal::__openmp_backend_tag, _ExecutionPolicy&&, _Index __n, _Tp __initial,
                       _Rp __reduce, _Cp __combine, _Sp __scan, _Ap __apex)
{
    if (__n <= __default_chunk_size)
    {
        _Tp __sum = __initial;
        if (__n)
        {
            __sum = __combine(__sum, __reduce(_Index(0), __n));
        }
        __apex(__sum);
        if (__n)
        {
            __scan(_Index(0), __n, __initial);
        }
        return;
    }

    if (omp_in_parallel())
    {
        __pstl::__omp_backend::__parallel_strict_scan_body<_ExecutionPolicy>(__n, __initial, __reduce, __combine,
                                                                             __scan, __apex);
    }
    else
    {
        _PSTL_PRAGMA(omp parallel)
        _PSTL_PRAGMA(omp single nowait)
        {
            __pstl::__omp_backend::__parallel_strict_scan_body<_ExecutionPolicy>(__n, __initial, __reduce, __combine,
                                                                                 __scan, __apex);
        }
    }
}

} // namespace __omp_backend
} // namespace __pstl
#endif // _PSTL_INTERNAL_OMP_PARALLEL_SCAN_H
