// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_FOR_EACH_H
#define _LIBCPP___ALGORITHM_FOR_EACH_H

#include <__algorithm/for_each_segment.h>
#include <__config>
#include <__functional/identity.h>
#include <__iterator/segmented_iterator.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/invoke.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _InputIterator, class _Sent, class _Func, class _Proj>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 _InputIterator
__for_each(_InputIterator __first, _Sent __last, _Func& __f, _Proj& __proj) {
  for (; __first != __last; ++__first)
    std::__invoke(__f, std::__invoke(__proj, *__first));
  return __first;
}

#ifndef _LIBCPP_CXX03_LANG
template <class _SegmentedIterator,
          class _Func,
          class _Proj,
          __enable_if_t<__is_segmented_iterator<_SegmentedIterator>::value, int> = 0>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 _SegmentedIterator
__for_each(_SegmentedIterator __first, _SegmentedIterator __last, _Func& __func, _Proj& __proj) {
  using __local_iterator_t = typename __segmented_iterator_traits<_SegmentedIterator>::__local_iterator;
  std::__for_each_segment(__first, __last, [&](__local_iterator_t __lfirst, __local_iterator_t __llast) {
    std::__for_each(__lfirst, __llast, __func, __proj);
  });
  return __last;
}
#endif // !_LIBCPP_CXX03_LANG

template <class _InputIterator, class _Func>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 _Func
for_each(_InputIterator __first, _InputIterator __last, _Func __f) {
  __identity __proj;
  std::__for_each(__first, __last, __f, __proj);
  return __f;
}

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_FOR_EACH_H
