// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FILESYSTEM_PERM_OPTIONS_H
#define _LIBCPP___FILESYSTEM_PERM_OPTIONS_H

#include <__availability>
#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

enum class _LIBCPP_ENUM_VIS perm_options : unsigned char {
  replace = 1,
  add = 2,
  remove = 4,
  nofollow = 8
};

_LIBCPP_INLINE_VISIBILITY
inline constexpr perm_options operator&(perm_options __lhs, perm_options __rhs) {
  return static_cast<perm_options>(static_cast<unsigned>(__lhs) &
                                   static_cast<unsigned>(__rhs));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr perm_options operator|(perm_options __lhs, perm_options __rhs) {
  return static_cast<perm_options>(static_cast<unsigned>(__lhs) |
                                   static_cast<unsigned>(__rhs));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr perm_options operator^(perm_options __lhs, perm_options __rhs) {
  return static_cast<perm_options>(static_cast<unsigned>(__lhs) ^
                                   static_cast<unsigned>(__rhs));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr perm_options operator~(perm_options __lhs) {
  return static_cast<perm_options>(~static_cast<unsigned>(__lhs));
}

_LIBCPP_INLINE_VISIBILITY
inline perm_options& operator&=(perm_options& __lhs, perm_options __rhs) {
  return __lhs = __lhs & __rhs;
}

_LIBCPP_INLINE_VISIBILITY
inline perm_options& operator|=(perm_options& __lhs, perm_options __rhs) {
  return __lhs = __lhs | __rhs;
}

_LIBCPP_INLINE_VISIBILITY
inline perm_options& operator^=(perm_options& __lhs, perm_options __rhs) {
  return __lhs = __lhs ^ __rhs;
}

_LIBCPP_END_NAMESPACE_FILESYSTEM

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___FILESYSTEM_PERM_OPTIONS_H
