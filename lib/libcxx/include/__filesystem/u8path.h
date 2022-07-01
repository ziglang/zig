// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FILESYSTEM_U8PATH_H
#define _LIBCPP___FILESYSTEM_U8PATH_H

#include <__availability>
#include <__config>
#include <__filesystem/path.h>
#include <type_traits>

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

_LIBCPP_AVAILABILITY_FILESYSTEM_PUSH

template <class _InputIt>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_DEPRECATED_WITH_CHAR8_T
    typename enable_if<__is_pathable<_InputIt>::value, path>::type
    u8path(_InputIt __f, _InputIt __l) {
  static_assert(
#ifndef _LIBCPP_HAS_NO_CHAR8_T
      is_same<typename __is_pathable<_InputIt>::__char_type, char8_t>::value ||
#endif
      is_same<typename __is_pathable<_InputIt>::__char_type, char>::value,
      "u8path(Iter, Iter) requires Iter have a value_type of type 'char'"
      " or 'char8_t'");
#if defined(_LIBCPP_WIN32API)
  string __tmp(__f, __l);
  using _CVT = __widen_from_utf8<sizeof(wchar_t) * __CHAR_BIT__>;
  _VSTD::wstring __w;
  __w.reserve(__tmp.size());
  _CVT()(back_inserter(__w), __tmp.data(), __tmp.data() + __tmp.size());
  return path(__w);
#else
  return path(__f, __l);
#endif /* !_LIBCPP_WIN32API */
}

#if defined(_LIBCPP_WIN32API)
template <class _InputIt>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_DEPRECATED_WITH_CHAR8_T
    typename enable_if<__is_pathable<_InputIt>::value, path>::type
    u8path(_InputIt __f, _NullSentinel) {
  static_assert(
#ifndef _LIBCPP_HAS_NO_CHAR8_T
      is_same<typename __is_pathable<_InputIt>::__char_type, char8_t>::value ||
#endif
      is_same<typename __is_pathable<_InputIt>::__char_type, char>::value,
      "u8path(Iter, Iter) requires Iter have a value_type of type 'char'"
      " or 'char8_t'");
  string __tmp;
  const char __sentinel = char{};
  for (; *__f != __sentinel; ++__f)
    __tmp.push_back(*__f);
  using _CVT = __widen_from_utf8<sizeof(wchar_t) * __CHAR_BIT__>;
  _VSTD::wstring __w;
  __w.reserve(__tmp.size());
  _CVT()(back_inserter(__w), __tmp.data(), __tmp.data() + __tmp.size());
  return path(__w);
}
#endif /* _LIBCPP_WIN32API */

template <class _Source>
_LIBCPP_INLINE_VISIBILITY _LIBCPP_DEPRECATED_WITH_CHAR8_T
    typename enable_if<__is_pathable<_Source>::value, path>::type
    u8path(const _Source& __s) {
  static_assert(
#ifndef _LIBCPP_HAS_NO_CHAR8_T
      is_same<typename __is_pathable<_Source>::__char_type, char8_t>::value ||
#endif
      is_same<typename __is_pathable<_Source>::__char_type, char>::value,
      "u8path(Source const&) requires Source have a character type of type "
      "'char' or 'char8_t'");
#if defined(_LIBCPP_WIN32API)
  using _Traits = __is_pathable<_Source>;
  return u8path(_VSTD::__unwrap_iter(_Traits::__range_begin(__s)), _VSTD::__unwrap_iter(_Traits::__range_end(__s)));
#else
  return path(__s);
#endif
}

_LIBCPP_AVAILABILITY_FILESYSTEM_POP

_LIBCPP_END_NAMESPACE_FILESYSTEM

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___FILESYSTEM_U8PATH_H
