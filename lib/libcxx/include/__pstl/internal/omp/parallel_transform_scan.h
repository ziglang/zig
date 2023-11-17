// -*- C++ -*-
// -*-===----------------------------------------------------------------------===//
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_INTERNAL_OMP_PARALLEL_TRANSFORM_SCAN_H
#define _PSTL_INTERNAL_OMP_PARALLEL_TRANSFORM_SCAN_H

#include "util.h"

namespace __pstl
{
namespace __omp_backend
{

template <class _ExecutionPolicy, class _Index, class _Up, class _Tp, class _Cp, class _Rp, class _Sp>
_Tp
__parallel_transform_scan(__pstl::__internal::__openmp_backend_tag, _ExecutionPolicy&&, _Index __n, _Up /* __u */,
                          _Tp __init, _Cp /* __combine */, _Rp /* __brick_reduce */, _Sp __scan)
{
    // TODO: parallelize this function.
    return __scan(_Index(0), __n, __init);
}

} // namespace __omp_backend
} // namespace __pstl
#endif // _PSTL_INTERNAL_OMP_PARALLEL_TRANSFORM_SCAN_H
