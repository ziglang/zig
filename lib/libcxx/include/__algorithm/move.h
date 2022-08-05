//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_MOVE_H
#define _LIBCPP___ALGORITHM_MOVE_H

#include <__algorithm/unwrap_iter.h>
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

// move

template <class _InIter, class _Sent, class _OutIter>
inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_AFTER_CXX14
pair<_InIter, _OutIter> __move_impl(_InIter __first, _Sent __last, _OutIter __result) {
  while (__first != __last) {
    *__result = std::move(*__first);
    ++__first;
    ++__result;
  }
  return std::make_pair(std::move(__first), std::move(__result));
}

template <class _InType,
          class _OutType,
          class = __enable_if_t<is_same<typename remove_const<_InType>::type, _OutType>::value
                             && is_trivially_move_assignable<_OutType>::value> >
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
pair<_InType*, _OutType*> __move_impl(_InType* __first, _InType* __last, _OutType* __result) {
  if (__libcpp_is_constant_evaluated()
// TODO: Remove this once GCC supports __builtin_memmove during constant evaluation
#ifndef _LIBCPP_COMPILER_GCC
   && !is_trivially_copyable<_InType>::value
#endif
     )
    return std::__move_impl<_InType*, _InType*, _OutType*>(__first, __last, __result);
  const size_t __n = static_cast<size_t>(__last - __first);
  ::__builtin_memmove(__result, __first, __n * sizeof(_OutType));
  return std::make_pair(__first + __n, __result + __n);
}

template <class>
struct __is_trivially_move_assignable_unwrapped_impl : false_type {};

template <class _Type>
struct __is_trivially_move_assignable_unwrapped_impl<_Type*> : is_trivially_move_assignable<_Type> {};

template <class _Iter>
struct __is_trivially_move_assignable_unwrapped
    : __is_trivially_move_assignable_unwrapped_impl<decltype(std::__unwrap_iter<_Iter>(std::declval<_Iter>()))> {};

template <class _InIter,
          class _OutIter,
          __enable_if_t<is_same<typename remove_const<typename iterator_traits<_InIter>::value_type>::type,
                                typename iterator_traits<_OutIter>::value_type>::value
                     && __is_cpp17_contiguous_iterator<_InIter>::value
                     && __is_cpp17_contiguous_iterator<_OutIter>::value
                     && is_trivially_move_assignable<__iter_value_type<_OutIter> >::value, int> = 0>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX14
pair<reverse_iterator<_InIter>, reverse_iterator<_OutIter> >
__move_impl(reverse_iterator<_InIter> __first,
            reverse_iterator<_InIter> __last,
            reverse_iterator<_OutIter> __result) {
  auto __first_base = std::__unwrap_iter(__first.base());
  auto __last_base = std::__unwrap_iter(__last.base());
  auto __result_base = std::__unwrap_iter(__result.base());
  auto __result_first = __result_base - (__first_base - __last_base);
  std::__move_impl(__last_base, __first_base, __result_first);
  return std::make_pair(__last, reverse_iterator<_OutIter>(std::__rewrap_iter(__result.base(), __result_first)));
}

template <class _InIter, class _Sent, class _OutIter>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
__enable_if_t<is_copy_constructible<_InIter>::value
           && is_copy_constructible<_Sent>::value
           && is_copy_constructible<_OutIter>::value, pair<_InIter, _OutIter> >
__move(_InIter __first, _Sent __last, _OutIter __result) {
  auto __ret = std::__move_impl(std::__unwrap_iter(__first), std::__unwrap_iter(__last), std::__unwrap_iter(__result));
  return std::make_pair(std::__rewrap_iter(__first, __ret.first), std::__rewrap_iter(__result, __ret.second));
}

template <class _InIter, class _Sent, class _OutIter>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11
__enable_if_t<!is_copy_constructible<_InIter>::value
           || !is_copy_constructible<_Sent>::value
           || !is_copy_constructible<_OutIter>::value, pair<_InIter, _OutIter> >
__move(_InIter __first, _Sent __last, _OutIter __result) {
  return std::__move_impl(std::move(__first), std::move(__last), std::move(__result));
}

template <class _InputIterator, class _OutputIterator>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX17
_OutputIterator move(_InputIterator __first, _InputIterator __last, _OutputIterator __result) {
  return std::__move(__first, __last, __result).second;
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_MOVE_H
