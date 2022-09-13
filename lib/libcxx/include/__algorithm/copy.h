//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_COPY_H
#define _LIBCPP___ALGORITHM_COPY_H

#include <__algorithm/unwrap_iter.h>
#include <__algorithm/unwrap_range.h>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__iterator/reverse_iterator.h>
#include <__utility/move.h>
#include <__utility/pair.h>
#include <cstring>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// copy

template <class _InIter, class _Sent, class _OutIter>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<_InIter, _OutIter> __copy_impl(_InIter __first, _Sent __last, _OutIter __result) {
  while (__first != __last) {
    *__result = *__first;
    ++__first;
    ++__result;
  }
  return pair<_InIter, _OutIter>(std::move(__first), std::move(__result));
}

template <class _InValueT,
          class _OutValueT,
          class = __enable_if_t<is_same<typename remove_const<_InValueT>::type, _OutValueT>::value
                             && is_trivially_copy_assignable<_OutValueT>::value> >
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<_InValueT*, _OutValueT*> __copy_impl(_InValueT* __first, _InValueT* __last, _OutValueT* __result) {
  if (__libcpp_is_constant_evaluated()
// TODO: Remove this once GCC supports __builtin_memmove during constant evaluation
#ifndef _LIBCPP_COMPILER_GCC
      && !is_trivially_copyable<_InValueT>::value
#endif
     )
    return std::__copy_impl<_InValueT*, _InValueT*, _OutValueT*>(__first, __last, __result);
  const size_t __n = static_cast<size_t>(__last - __first);
  if (__n > 0)
    ::__builtin_memmove(__result, __first, __n * sizeof(_OutValueT));
  return std::make_pair(__first + __n, __result + __n);
}

template <class _InIter, class _OutIter,
          __enable_if_t<is_same<typename remove_const<__iter_value_type<_InIter> >::type, __iter_value_type<_OutIter> >::value
                      && __is_cpp17_contiguous_iterator<typename _InIter::iterator_type>::value
                      && __is_cpp17_contiguous_iterator<typename _OutIter::iterator_type>::value
                      && is_trivially_copy_assignable<__iter_value_type<_OutIter> >::value
                      && __is_reverse_iterator<_InIter>::value
                      && __is_reverse_iterator<_OutIter>::value, int> = 0>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<_InIter, _OutIter>
__copy_impl(_InIter __first, _InIter __last, _OutIter __result) {
  auto __first_base = std::__unwrap_iter(__first.base());
  auto __last_base = std::__unwrap_iter(__last.base());
  auto __result_base = std::__unwrap_iter(__result.base());
  auto __result_first = __result_base - (__first_base - __last_base);
  std::__copy_impl(__last_base, __first_base, __result_first);
  return std::make_pair(__last, _OutIter(std::__rewrap_iter(__result.base(), __result_first)));
}

template <class _InIter, class _Sent, class _OutIter,
          __enable_if_t<!(is_copy_constructible<_InIter>::value
                       && is_copy_constructible<_Sent>::value
                       && is_copy_constructible<_OutIter>::value), int> = 0 >
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<_InIter, _OutIter> __copy(_InIter __first, _Sent __last, _OutIter __result) {
  return std::__copy_impl(std::move(__first), std::move(__last), std::move(__result));
}

template <class _InIter, class _Sent, class _OutIter,
          __enable_if_t<is_copy_constructible<_InIter>::value
                     && is_copy_constructible<_Sent>::value
                     && is_copy_constructible<_OutIter>::value, int> = 0>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<_InIter, _OutIter> __copy(_InIter __first, _Sent __last, _OutIter __result) {
  auto __range = std::__unwrap_range(__first, __last);
  auto __ret   = std::__copy_impl(std::move(__range.first), std::move(__range.second), std::__unwrap_iter(__result));
  return std::make_pair(
      std::__rewrap_range<_Sent>(__first, __ret.first), std::__rewrap_iter(__result, __ret.second));
}

template <class _InputIterator, class _OutputIterator>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX17
_OutputIterator
copy(_InputIterator __first, _InputIterator __last, _OutputIterator __result) {
  return std::__copy(__first, __last, __result).second;
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_COPY_H
