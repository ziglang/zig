//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_SET_DIFFERENCE_H
#define _LIBCPP___ALGORITHM_SET_DIFFERENCE_H

#include <__algorithm/comp.h>
#include <__algorithm/comp_ref_type.h>
#include <__algorithm/copy.h>
#include <__config>
#include <__functional/identity.h>
#include <__functional/invoke.h>
#include <__iterator/iterator_traits.h>
#include <__utility/move.h>
#include <__utility/pair.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template < class _Comp, class _InIter1, class _Sent1, class _InIter2, class _Sent2, class _OutIter>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 pair<__uncvref_t<_InIter1>, __uncvref_t<_OutIter> >
__set_difference(
    _InIter1&& __first1, _Sent1&& __last1, _InIter2&& __first2, _Sent2&& __last2, _OutIter&& __result, _Comp&& __comp) {
  while (__first1 != __last1 && __first2 != __last2) {
    if (__comp(*__first1, *__first2)) {
      *__result = *__first1;
      ++__first1;
      ++__result;
    } else if (__comp(*__first2, *__first1)) {
      ++__first2;
    } else {
      ++__first1;
      ++__first2;
    }
  }
  return std::__copy(std::move(__first1), std::move(__last1), std::move(__result));
}

template <class _InputIterator1, class _InputIterator2, class _OutputIterator, class _Compare>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 _OutputIterator set_difference(
    _InputIterator1 __first1,
    _InputIterator1 __last1,
    _InputIterator2 __first2,
    _InputIterator2 __last2,
    _OutputIterator __result,
    _Compare __comp) {
  typedef typename __comp_ref_type<_Compare>::type _Comp_ref;
  return std::__set_difference<_Comp_ref>(__first1, __last1, __first2, __last2, __result, __comp).second;
}

template <class _InputIterator1, class _InputIterator2, class _OutputIterator>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17 _OutputIterator set_difference(
    _InputIterator1 __first1,
    _InputIterator1 __last1,
    _InputIterator2 __first2,
    _InputIterator2 __last2,
    _OutputIterator __result) {
  return std::__set_difference(
      __first1,
      __last1,
      __first2,
      __last2,
      __result,
      __less<typename iterator_traits<_InputIterator1>::value_type,
             typename iterator_traits<_InputIterator2>::value_type>()).second;
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_SET_DIFFERENCE_H
