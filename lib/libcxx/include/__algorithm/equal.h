// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_EQUAL_H
#define _LIBCPP___ALGORITHM_EQUAL_H

#include <__algorithm/comp.h>
#include <__config>
#include <__iterator/distance.h>
#include <__iterator/iterator_traits.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _InputIterator1, class _InputIterator2, class _BinaryPredicate>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2, _BinaryPredicate __pred) {
  for (; __first1 != __last1; ++__first1, (void)++__first2)
    if (!__pred(*__first1, *__first2))
      return false;
  return true;
}

template <class _InputIterator1, class _InputIterator2>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2) {
  typedef typename iterator_traits<_InputIterator1>::value_type __v1;
  typedef typename iterator_traits<_InputIterator2>::value_type __v2;
  return _VSTD::equal(__first1, __last1, __first2, __equal_to<__v1, __v2>());
}

#if _LIBCPP_STD_VER > 11
template <class _BinaryPredicate, class _InputIterator1, class _InputIterator2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
__equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2, _InputIterator2 __last2,
        _BinaryPredicate __pred, input_iterator_tag, input_iterator_tag) {
  for (; __first1 != __last1 && __first2 != __last2; ++__first1, (void)++__first2)
    if (!__pred(*__first1, *__first2))
      return false;
  return __first1 == __last1 && __first2 == __last2;
}

template <class _BinaryPredicate, class _RandomAccessIterator1, class _RandomAccessIterator2>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
__equal(_RandomAccessIterator1 __first1, _RandomAccessIterator1 __last1, _RandomAccessIterator2 __first2,
        _RandomAccessIterator2 __last2, _BinaryPredicate __pred, random_access_iterator_tag,
        random_access_iterator_tag) {
  if (_VSTD::distance(__first1, __last1) != _VSTD::distance(__first2, __last2))
    return false;
  return _VSTD::equal<_RandomAccessIterator1, _RandomAccessIterator2,
                      _BinaryPredicate&>(__first1, __last1, __first2, __pred);
}

template <class _InputIterator1, class _InputIterator2, class _BinaryPredicate>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2, _InputIterator2 __last2,
      _BinaryPredicate __pred) {
  return _VSTD::__equal<_BinaryPredicate&>(
      __first1, __last1, __first2, __last2, __pred, typename iterator_traits<_InputIterator1>::iterator_category(),
      typename iterator_traits<_InputIterator2>::iterator_category());
}

template <class _InputIterator1, class _InputIterator2>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2, _InputIterator2 __last2) {
  typedef typename iterator_traits<_InputIterator1>::value_type __v1;
  typedef typename iterator_traits<_InputIterator2>::value_type __v2;
  return _VSTD::__equal(__first1, __last1, __first2, __last2, __equal_to<__v1, __v2>(),
                        typename iterator_traits<_InputIterator1>::iterator_category(),
                        typename iterator_traits<_InputIterator2>::iterator_category());
}
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_EQUAL_H
