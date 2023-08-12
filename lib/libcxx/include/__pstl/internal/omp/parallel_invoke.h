// -*- C++ -*-
// -*-===----------------------------------------------------------------------===//
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_INTERNAL_OMP_PARALLEL_INVOKE_H
#define _PSTL_INTERNAL_OMP_PARALLEL_INVOKE_H

#include "util.h"

namespace __pstl
{
namespace __omp_backend
{

template <typename _F1, typename _F2>
void
__parallel_invoke_body(_F1&& __f1, _F2&& __f2)
{
    _PSTL_PRAGMA(omp taskgroup)
    {
        _PSTL_PRAGMA(omp task untied mergeable) { std::forward<_F1>(__f1)(); }
        _PSTL_PRAGMA(omp task untied mergeable) { std::forward<_F2>(__f2)(); }
    }
}

template <class _ExecutionPolicy, typename _F1, typename _F2>
void
__parallel_invoke(__pstl::__internal::__openmp_backend_tag, _ExecutionPolicy&&, _F1&& __f1, _F2&& __f2)
{
    if (omp_in_parallel())
    {
        __pstl::__omp_backend::__parallel_invoke_body(std::forward<_F1>(__f1), std::forward<_F2>(__f2));
    }
    else
    {
        _PSTL_PRAGMA(omp parallel)
        _PSTL_PRAGMA(omp single nowait)
        __pstl::__omp_backend::__parallel_invoke_body(std::forward<_F1>(__f1), std::forward<_F2>(__f2));
    }
}

} // namespace __omp_backend
} // namespace __pstl
#endif // _PSTL_INTERNAL_OMP_PARALLEL_INVOKE_H
