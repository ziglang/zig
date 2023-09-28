// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _PSTL_GLUE_NUMERIC_DEFS_H
#define _PSTL_GLUE_NUMERIC_DEFS_H

#include <__config>
#include <iterator>

#include "execution_defs.h"

namespace std {
// [exclusive.scan]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Tp>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> exclusive_scan(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __result,
    _Tp __init);

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Tp, class _BinaryOperation>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> exclusive_scan(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __result,
    _Tp __init,
    _BinaryOperation __binary_op);

// [inclusive.scan]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> inclusive_scan(
    _ExecutionPolicy&& __exec, _ForwardIterator1 __first, _ForwardIterator1 __last, _ForwardIterator2 __result);

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryOperation>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> inclusive_scan(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __result,
    _BinaryOperation __binary_op);

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _Tp, class _BinaryOperation>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> inclusive_scan(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __result,
    _BinaryOperation __binary_op,
    _Tp __init);

// [transform.exclusive.scan]

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _Tp,
          class _BinaryOperation,
          class _UnaryOperation>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> transform_exclusive_scan(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __result,
    _Tp __init,
    _BinaryOperation __binary_op,
    _UnaryOperation __unary_op);

// [transform.inclusive.scan]

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _BinaryOperation,
          class _UnaryOperation,
          class _Tp>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> transform_inclusive_scan(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __result,
    _BinaryOperation __binary_op,
    _UnaryOperation __unary_op,
    _Tp __init);

template <class _ExecutionPolicy,
          class _ForwardIterator1,
          class _ForwardIterator2,
          class _UnaryOperation,
          class _BinaryOperation>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> transform_inclusive_scan(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __result,
    _BinaryOperation __binary_op,
    _UnaryOperation __unary_op);

// [adjacent.difference]

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2, class _BinaryOperation>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> adjacent_difference(
    _ExecutionPolicy&& __exec,
    _ForwardIterator1 __first,
    _ForwardIterator1 __last,
    _ForwardIterator2 __d_first,
    _BinaryOperation op);

template <class _ExecutionPolicy, class _ForwardIterator1, class _ForwardIterator2>
__pstl::__internal::__enable_if_execution_policy<_ExecutionPolicy, _ForwardIterator2> adjacent_difference(
    _ExecutionPolicy&& __exec, _ForwardIterator1 __first, _ForwardIterator1 __last, _ForwardIterator2 __d_first);

} // namespace std

#endif /* _PSTL_GLUE_NUMERIC_DEFS_H */
