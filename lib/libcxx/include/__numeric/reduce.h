// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___NUMERIC_REDUCE_H
#define _LIBCPP___NUMERIC_REDUCE_H

#include <__config>
#include <__functional/operations.h>
#include <__iterator/iterator_traits.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 14
template <class _InputIterator, class _Tp, class _BinaryOp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 _Tp reduce(_InputIterator __first, _InputIterator __last,
                                                                   _Tp __init, _BinaryOp __b) {
  for (; __first != __last; ++__first)
    __init = __b(__init, *__first);
  return __init;
}

template <class _InputIterator, class _Tp>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 _Tp reduce(_InputIterator __first, _InputIterator __last,
                                                                   _Tp __init) {
  return _VSTD::reduce(__first, __last, __init, _VSTD::plus<>());
}

template <class _InputIterator>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 typename iterator_traits<_InputIterator>::value_type
reduce(_InputIterator __first, _InputIterator __last) {
  return _VSTD::reduce(__first, __last, typename iterator_traits<_InputIterator>::value_type{});
}
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___NUMERIC_REDUCE_H
