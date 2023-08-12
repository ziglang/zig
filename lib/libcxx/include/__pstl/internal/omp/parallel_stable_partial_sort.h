// -*- C++ -*-
// -*-===----------------------------------------------------------------------===//
//
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_INTERNAL_OMP_PARALLEL_STABLE_PARTIAL_SORT_H
#define _PSTL_INTERNAL_OMP_PARALLEL_STABLE_PARTIAL_SORT_H

#include "util.h"

namespace __pstl
{
namespace __omp_backend
{

template <typename _RandomAccessIterator, typename _Compare, typename _LeafSort>
void
__parallel_stable_partial_sort(__pstl::__internal::__openmp_backend_tag, _RandomAccessIterator __xs,
                               _RandomAccessIterator __xe, _Compare __comp, _LeafSort __leaf_sort,
                               std::size_t /* __nsort */)
{
    // TODO: "Parallel partial sort needs to be implemented.");
    __leaf_sort(__xs, __xe, __comp);
}

} // namespace __omp_backend
} // namespace __pstl
#endif // _PSTL_INTERNAL_OMP_PARALLEL_STABLE_PARTIAL_SORT_H
