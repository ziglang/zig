// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_FIND_H
#define _LIBCPP___ALGORITHM_FIND_H

#include <__algorithm/unwrap_iter.h>
#include <__config>
#include <__functional/identity.h>
#include <__functional/invoke.h>
#include <__string/constexpr_c_functions.h>
#include <__type_traits/is_same.h>

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
#  include <cwchar>
#endif

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Iter, class _Sent, class _Tp, class _Proj>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _Iter
__find_impl(_Iter __first, _Sent __last, const _Tp& __value, _Proj& __proj) {
  for (; __first != __last; ++__first)
    if (std::__invoke(__proj, *__first) == __value)
      break;
  return __first;
}

template <class _Tp,
          class _Up,
          class _Proj,
          __enable_if_t<__is_identity<_Proj>::value && __libcpp_is_trivially_equality_comparable<_Tp, _Up>::value &&
                            sizeof(_Tp) == 1,
                        int> = 0>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _Tp*
__find_impl(_Tp* __first, _Tp* __last, const _Up& __value, _Proj&) {
  if (auto __ret = std::__constexpr_memchr(__first, __value, __last - __first))
    return __ret;
  return __last;
}

#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template <class _Tp,
          class _Up,
          class _Proj,
          __enable_if_t<__is_identity<_Proj>::value && __libcpp_is_trivially_equality_comparable<_Tp, _Up>::value &&
                            sizeof(_Tp) == sizeof(wchar_t) && _LIBCPP_ALIGNOF(_Tp) >= _LIBCPP_ALIGNOF(wchar_t),
                        int> = 0>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _Tp*
__find_impl(_Tp* __first, _Tp* __last, const _Up& __value, _Proj&) {
  if (auto __ret = std::__constexpr_wmemchr(__first, __value, __last - __first))
    return __ret;
  return __last;
}
#endif // _LIBCPP_HAS_NO_WIDE_CHARACTERS

template <class _InputIterator, class _Tp>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX20 _InputIterator
find(_InputIterator __first, _InputIterator __last, const _Tp& __value) {
  __identity __proj;
  return std::__rewrap_iter(
      __first, std::__find_impl(std::__unwrap_iter(__first), std::__unwrap_iter(__last), __value, __proj));
}

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_FIND_H
