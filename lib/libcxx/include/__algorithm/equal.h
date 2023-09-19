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
#include <__algorithm/unwrap_iter.h>
#include <__config>
#include <__functional/identity.h>
#include <__functional/invoke.h>
#include <__iterator/distance.h>
#include <__iterator/iterator_traits.h>
#include <__string/constexpr_c_functions.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_constant_evaluated.h>
#include <__type_traits/is_equality_comparable.h>
#include <__type_traits/is_volatile.h>
#include <__type_traits/predicate_traits.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _InputIterator1, class _InputIterator2, class _BinaryPredicate>
_LIBCPP_NODISCARD inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool __equal_iter_impl(
    _InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2, _BinaryPredicate& __pred) {
  for (; __first1 != __last1; ++__first1, (void)++__first2)
    if (!__pred(*__first1, *__first2))
      return false;
  return true;
}

template <
    class _Tp,
    class _Up,
    class _BinaryPredicate,
    __enable_if_t<__is_trivial_equality_predicate<_BinaryPredicate, _Tp, _Up>::value && !is_volatile<_Tp>::value &&
                      !is_volatile<_Up>::value && __libcpp_is_trivially_equality_comparable<_Tp, _Up>::value,
                  int> = 0>
_LIBCPP_NODISCARD inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool
__equal_iter_impl(_Tp* __first1, _Tp* __last1, _Up* __first2, _BinaryPredicate&) {
  return std::__constexpr_memcmp_equal(__first1, __first2, __element_count(__last1 - __first1));
}

template <class _InputIterator1, class _InputIterator2, class _BinaryPredicate>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool
equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2, _BinaryPredicate __pred) {
  return std::__equal_iter_impl(
      std::__unwrap_iter(__first1), std::__unwrap_iter(__last1), std::__unwrap_iter(__first2), __pred);
}

template <class _InputIterator1, class _InputIterator2>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool
equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2) {
  return std::equal(__first1, __last1, __first2, __equal_to());
}

#if _LIBCPP_STD_VER >= 14
template <class _BinaryPredicate, class _InputIterator1, class _InputIterator2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool
__equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2, _InputIterator2 __last2,
        _BinaryPredicate __pred, input_iterator_tag, input_iterator_tag) {
  for (; __first1 != __last1 && __first2 != __last2; ++__first1, (void)++__first2)
    if (!__pred(*__first1, *__first2))
      return false;
  return __first1 == __last1 && __first2 == __last2;
}

template <class _Iter1, class _Sent1, class _Iter2, class _Sent2, class _Pred, class _Proj1, class _Proj2>
_LIBCPP_NODISCARD inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool __equal_impl(
    _Iter1 __first1, _Sent1 __last1, _Iter2 __first2, _Sent2 __last2, _Pred& __comp, _Proj1& __proj1, _Proj2& __proj2) {
  while (__first1 != __last1 && __first2 != __last2) {
    if (!std::__invoke(__comp, std::__invoke(__proj1, *__first1), std::__invoke(__proj2, *__first2)))
      return false;
    ++__first1;
    ++__first2;
  }
  return __first1 == __last1 && __first2 == __last2;
}

template <class _Tp,
          class _Up,
          class _Pred,
          class _Proj1,
          class _Proj2,
          __enable_if_t<__is_trivial_equality_predicate<_Pred, _Tp, _Up>::value && __is_identity<_Proj1>::value &&
                            __is_identity<_Proj2>::value && !is_volatile<_Tp>::value && !is_volatile<_Up>::value &&
                            __libcpp_is_trivially_equality_comparable<_Tp, _Up>::value,
                        int> = 0>
_LIBCPP_NODISCARD inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool __equal_impl(
    _Tp* __first1, _Tp* __last1, _Up* __first2, _Up*, _Pred&, _Proj1&, _Proj2&) {
  return std::__constexpr_memcmp_equal(__first1, __first2, __element_count(__last1 - __first1));
}

template <class _BinaryPredicate, class _RandomAccessIterator1, class _RandomAccessIterator2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool
__equal(_RandomAccessIterator1 __first1, _RandomAccessIterator1 __last1, _RandomAccessIterator2 __first2,
        _RandomAccessIterator2 __last2, _BinaryPredicate __pred, random_access_iterator_tag,
        random_access_iterator_tag) {
  if (_VSTD::distance(__first1, __last1) != _VSTD::distance(__first2, __last2))
    return false;
  __identity __proj;
  return std::__equal_impl(
      std::__unwrap_iter(__first1),
      std::__unwrap_iter(__last1),
      std::__unwrap_iter(__first2),
      std::__unwrap_iter(__last2),
      __pred,
      __proj,
      __proj);
}

template <class _InputIterator1, class _InputIterator2, class _BinaryPredicate>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool
equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2, _InputIterator2 __last2,
      _BinaryPredicate __pred) {
  return _VSTD::__equal<_BinaryPredicate&>(
      __first1, __last1, __first2, __last2, __pred, typename iterator_traits<_InputIterator1>::iterator_category(),
      typename iterator_traits<_InputIterator2>::iterator_category());
}

template <class _InputIterator1, class _InputIterator2>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX20 bool
equal(_InputIterator1 __first1, _InputIterator1 __last1, _InputIterator2 __first2, _InputIterator2 __last2) {
  return std::__equal(
      __first1,
      __last1,
      __first2,
      __last2,
      __equal_to(),
      typename iterator_traits<_InputIterator1>::iterator_category(),
      typename iterator_traits<_InputIterator2>::iterator_category());
}
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_EQUAL_H
