// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_FOR_EACH_N_H
#define _LIBCPP___ALGORITHM_FOR_EACH_N_H

#include <__algorithm/for_each.h>
#include <__algorithm/for_each_n_segment.h>
#include <__config>
#include <__functional/identity.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/segmented_iterator.h>
#include <__type_traits/disjunction.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/invoke.h>
#include <__type_traits/negation.h>
#include <__utility/convert_to_integral.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _InputIterator,
          class _Size,
          class _Func,
          class _Proj,
          __enable_if_t<!__has_random_access_iterator_category<_InputIterator>::value &&
                            _Or< _Not<__is_segmented_iterator<_InputIterator> >,
                                 _Not<__has_random_access_local_iterator<_InputIterator> > >::value,
                        int> = 0>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 _InputIterator
__for_each_n(_InputIterator __first, _Size __orig_n, _Func& __f, _Proj& __proj) {
  typedef decltype(std::__convert_to_integral(__orig_n)) _IntegralSize;
  _IntegralSize __n = __orig_n;
  while (__n > 0) {
    std::__invoke(__f, std::__invoke(__proj, *__first));
    ++__first;
    --__n;
  }
  return std::move(__first);
}

template <class _RandIter,
          class _Size,
          class _Func,
          class _Proj,
          __enable_if_t<__has_random_access_iterator_category<_RandIter>::value, int> = 0>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 _RandIter
__for_each_n(_RandIter __first, _Size __orig_n, _Func& __f, _Proj& __proj) {
  typename std::iterator_traits<_RandIter>::difference_type __n = __orig_n;
  auto __last                                                   = __first + __n;
  std::__for_each(__first, __last, __f, __proj);
  return __last;
}

#ifndef _LIBCPP_CXX03_LANG
template <class _SegmentedIterator,
          class _Size,
          class _Func,
          class _Proj,
          __enable_if_t<!__has_random_access_iterator_category<_SegmentedIterator>::value &&
                            __is_segmented_iterator<_SegmentedIterator>::value &&
                            __has_random_access_iterator_category<
                                typename __segmented_iterator_traits<_SegmentedIterator>::__local_iterator>::value,
                        int> = 0>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 _SegmentedIterator
__for_each_n(_SegmentedIterator __first, _Size __orig_n, _Func& __f, _Proj& __proj) {
  using __local_iterator_t = typename __segmented_iterator_traits<_SegmentedIterator>::__local_iterator;
  return std::__for_each_n_segment(__first, __orig_n, [&](__local_iterator_t __lfirst, __local_iterator_t __llast) {
    std::__for_each(__lfirst, __llast, __f, __proj);
  });
}
#endif // !_LIBCPP_CXX03_LANG

#if _LIBCPP_STD_VER >= 17

template <class _InputIterator, class _Size, class _Func>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 _InputIterator
for_each_n(_InputIterator __first, _Size __orig_n, _Func __f) {
  __identity __proj;
  return std::__for_each_n(__first, __orig_n, __f, __proj);
}

#endif // _LIBCPP_STD_VER >= 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ALGORITHM_FOR_EACH_N_H
