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

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

_LIBCPP_AVAILABILITY_FILESYSTEM_PUSH

enum class _LIBCPP_ENUM_VIS perm_options : unsigned char {
  replace = 1,
  add = 2,
  remove = 4,
  nofollow = 8
};

_LIBCPP_INLINE_VISIBILITY
inline constexpr perm_options operator&(perm_options _LHS, perm_options _RHS) {
  return static_cast<perm_options>(static_cast<unsigned>(_LHS) &
                                   static_cast<unsigned>(_RHS));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr perm_options operator|(perm_options _LHS, perm_options _RHS) {
  return static_cast<perm_options>(static_cast<unsigned>(_LHS) |
                                   static_cast<unsigned>(_RHS));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr perm_options operator^(perm_options _LHS, perm_options _RHS) {
  return static_cast<perm_options>(static_cast<unsigned>(_LHS) ^
                                   static_cast<unsigned>(_RHS));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr perm_options operator~(perm_options _LHS) {
  return static_cast<perm_options>(~static_cast<unsigned>(_LHS));
}

_LIBCPP_INLINE_VISIBILITY
inline perm_options& operator&=(perm_options& _LHS, perm_options _RHS) {
  return _LHS = _LHS & _RHS;
}

_LIBCPP_INLINE_VISIBILITY
inline perm_options& operator|=(perm_options& _LHS, perm_options _RHS) {
  return _LHS = _LHS | _RHS;
}

_LIBCPP_INLINE_VISIBILITY
inline perm_options& operator^=(perm_options& _LHS, perm_options _RHS) {
  return _LHS = _LHS ^ _RHS;
}

_LIBCPP_AVAILABILITY_FILESYSTEM_POP

_LIBCPP_END_NAMESPACE_FILESYSTEM

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___FILESYSTEM_PERM_OPTIONS_H
