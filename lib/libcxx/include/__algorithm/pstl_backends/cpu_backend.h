//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKEND_H
#define _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKEND_H

#include <__config>

/*

  // _Functor takes a subrange for [__first, __last) that should be executed in serial
  template <class _RandomAccessIterator, class _Functor>
  optional<__empty> __parallel_for(_RandomAccessIterator __first, _RandomAccessIterator __last, _Functor __func);

  template <class _Iterator, class _UnaryOp, class _Tp, class _BinaryOp, class _Reduction>
  optional<_Tp>
  __parallel_transform_reduce(_Iterator __first, _Iterator __last, _UnaryOp, _Tp __init, _BinaryOp, _Reduction);

  // Cancel the execution of other jobs - they aren't needed anymore
  void __cancel_execution();

  template <class _RandomAccessIterator1,
            class _RandomAccessIterator2,
            class _RandomAccessIterator3,
            class _Compare,
            class _LeafMerge>
  optional<void> __parallel_merge(
      _RandomAccessIterator1 __first1,
      _RandomAccessIterator1 __last1,
      _RandomAccessIterator2 __first2,
      _RandomAccessIterator2 __last2,
      _RandomAccessIterator3 __outit,
      _Compare __comp,
      _LeafMerge __leaf_merge);

  template <class _RandomAccessIterator, class _Comp, class _LeafSort>
  void __parallel_stable_sort(_RandomAccessIterator __first,
                              _RandomAccessIterator __last,
                              _Comp __comp,
                              _LeafSort __leaf_sort);

  TODO: Document the parallel backend

Exception handling
==================

CPU backends are expected to report errors (i.e. failure to allocate) by returning a disengaged `optional` from their
implementation. Exceptions shouldn't be used to report an internal failure-to-allocate, since all exceptions are turned
into a program termination at the front-end level. When a backend returns a disengaged `optional` to the frontend, the
frontend will turn that into a call to `std::__throw_bad_alloc();` to report the internal failure to the user.
*/

#include <__algorithm/pstl_backends/cpu_backends/any_of.h>
#include <__algorithm/pstl_backends/cpu_backends/backend.h>
#include <__algorithm/pstl_backends/cpu_backends/fill.h>
#include <__algorithm/pstl_backends/cpu_backends/find_if.h>
#include <__algorithm/pstl_backends/cpu_backends/for_each.h>
#include <__algorithm/pstl_backends/cpu_backends/merge.h>
#include <__algorithm/pstl_backends/cpu_backends/stable_sort.h>
#include <__algorithm/pstl_backends/cpu_backends/transform.h>
#include <__algorithm/pstl_backends/cpu_backends/transform_reduce.h>

#endif // _LIBCPP___ALGORITHM_PSTL_BACKENDS_CPU_BACKEND_H
