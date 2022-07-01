// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_IS_PERMUTATION_H
#define _LIBCPP___ALGORITHM_IS_PERMUTATION_H

#include <__algorithm/comp.h>
#include <__config>
#include <__iterator/distance.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/next.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
is_permutation(_ForwardIterator1 __first1, _ForwardIterator1 __last1, _ForwardIterator2 __first2,
               _BinaryPredicate __pred) {
  //  shorten sequences as much as possible by lopping of any equal prefix
  for (; __first1 != __last1; ++__first1, (void)++__first2)
    if (!__pred(*__first1, *__first2))
      break;
  if (__first1 == __last1)
    return true;

  //  __first1 != __last1 && *__first1 != *__first2
  typedef typename iterator_traits<_ForwardIterator1>::difference_type _D1;
  _D1 __l1 = _VSTD::distance(__first1, __last1);
  if (__l1 == _D1(1))
    return false;
  _ForwardIterator2 __last2 = _VSTD::next(__first2, __l1);
  // For each element in [f1, l1) see if there are the same number of
  //    equal elements in [f2, l2)
  for (_ForwardIterator1 __i = __first1; __i != __last1; ++__i) {
    //  Have we already counted the number of *__i in [f1, l1)?
    _ForwardIterator1 __match = __first1;
    for (; __match != __i; ++__match)
      if (__pred(*__match, *__i))
        break;
    if (__match == __i) {
      // Count number of *__i in [f2, l2)
      _D1 __c2 = 0;
      for (_ForwardIterator2 __j = __first2; __j != __last2; ++__j)
        if (__pred(*__i, *__j))
          ++__c2;
      if (__c2 == 0)
        return false;
      // Count number of *__i in [__i, l1) (we can start with 1)
      _D1 __c1 = 1;
      for (_ForwardIterator1 __j = _VSTD::next(__i); __j != __last1; ++__j)
        if (__pred(*__i, *__j))
          ++__c1;
      if (__c1 != __c2)
        return false;
    }
  }
  return true;
}

template <class _ForwardIterator1, class _ForwardIterator2>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
is_permutation(_ForwardIterator1 __first1, _ForwardIterator1 __last1, _ForwardIterator2 __first2) {
  typedef typename iterator_traits<_ForwardIterator1>::value_type __v1;
  typedef typename iterator_traits<_ForwardIterator2>::value_type __v2;
  return _VSTD::is_permutation(__first1, __last1, __first2, __equal_to<__v1, __v2>());
}

#if _LIBCPP_STD_VER > 11
template <class _BinaryPredicate, class _ForwardIterator1, class _ForwardIterator2>
_LIBCPP_CONSTEXPR_AFTER_CXX17 bool
__is_permutation(_ForwardIterator1 __first1, _ForwardIterator1 __last1, _ForwardIterator2 __first2,
                 _ForwardIterator2 __last2, _BinaryPredicate __pred, forward_iterator_tag, forward_iterator_tag) {
  //  shorten sequences as much as possible by lopping of any equal prefix
  for (; __first1 != __last1 && __first2 != __last2; ++__first1, (void)++__first2)
    if (!__pred(*__first1, *__first2))
      break;
  if (__first1 == __last1)
    return __first2 == __last2;
  else if (__first2 == __last2)
    return false;

  typedef typename iterator_traits<_ForwardIterator1>::difference_type _D1;
  _D1 __l1 = _VSTD::distance(__first1, __last1);

  typedef typename iterator_traits<_ForwardIterator2>::difference_type _D2;
  _D2 __l2 = _VSTD::distance(__first2, __last2);
  if (__l1 != __l2)
    return false;

  // For each element in [f1, l1) see if there are the same number of
  //    equal elements in [f2, l2)
  for (_ForwardIterator1 __i = __first1; __i != __last1; ++__i) {
    //  Have we already counted the number of *__i in [f1, l1)?
    _ForwardIterator1 __match = __first1;
    for (; __match != __i; ++__match)
      if (__pred(*__match, *__i))
        break;
    if (__match == __i) {
      // Count number of *__i in [f2, l2)
      _D1 __c2 = 0;
      for (_ForwardIterator2 __j = __first2; __j != __last2; ++__j)
        if (__pred(*__i, *__j))
          ++__c2;
      if (__c2 == 0)
        return false;
      // Count number of *__i in [__i, l1) (we can start with 1)
      _D1 __c1 = 1;
      for (_ForwardIterator1 __j = _VSTD::next(__i); __j != __last1; ++__j)
        if (__pred(*__i, *__j))
          ++__c1;
      if (__c1 != __c2)
        return false;
    }
  }
  return true;
}

template <class _BinaryPredicate, class _RandomAccessIterator1, class _RandomAccessIterator2>
_LIBCPP_CONSTEXPR_AFTER_CXX17 bool __is_permutation(_RandomAccessIterator1 __first1, _RandomAccessIterator2 __last1,
                                                    _RandomAccessIterator1 __first2, _RandomAccessIterator2 __last2,
                                                    _BinaryPredicate __pred, random_access_iterator_tag,
                                                    random_access_iterator_tag) {
  if (_VSTD::distance(__first1, __last1) != _VSTD::distance(__first2, __last2))
    return false;
  return _VSTD::is_permutation<_RandomAccessIterator1, _RandomAccessIterator2,
                               _BinaryPredicate&>(__first1, __last1, __first2, __pred);
}

template <class _ForwardIterator1, class _ForwardIterator2, class _BinaryPredicate>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
is_permutation(_ForwardIterator1 __first1, _ForwardIterator1 __last1, _ForwardIterator2 __first2,
               _ForwardIterator2 __last2, _BinaryPredicate __pred) {
  return _VSTD::__is_permutation<_BinaryPredicate&>(
      __first1, __last1, __first2, __last2, __pred, typename iterator_traits<_ForwardIterator1>::iterator_category(),
      typename iterator_traits<_ForwardIterator2>::iterator_category());
}

template <class _ForwardIterator1, class _ForwardIterator2>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17 bool
is_permutation(_ForwardIterator1 __first1, _ForwardIterator1 __last1, _ForwardIterator2 __first2,
               _ForwardIterator2 __last2) {
  typedef typename iterator_traits<_ForwardIterator1>::value_type __v1;
  typedef typename iterator_traits<_ForwardIterator2>::value_type __v2;
  return _VSTD::__is_permutation(__first1, __last1, __first2, __last2, __equal_to<__v1, __v2>(),
                                 typename iterator_traits<_ForwardIterator1>::iterator_category(),
                                 typename iterator_traits<_ForwardIterator2>::iterator_category());
}
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_IS_PERMUTATION_H
