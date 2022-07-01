// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FILESYSTEM_COPY_OPTIONS_H
#define _LIBCPP___FILESYSTEM_COPY_OPTIONS_H

#include <__availability>
#include <__config>

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

_LIBCPP_AVAILABILITY_FILESYSTEM_PUSH

enum class _LIBCPP_ENUM_VIS copy_options : unsigned short {
  none = 0,
  skip_existing = 1,
  overwrite_existing = 2,
  update_existing = 4,
  recursive = 8,
  copy_symlinks = 16,
  skip_symlinks = 32,
  directories_only = 64,
  create_symlinks = 128,
  create_hard_links = 256,
  __in_recursive_copy = 512,
};

_LIBCPP_INLINE_VISIBILITY
inline constexpr copy_options operator&(copy_options _LHS, copy_options _RHS) {
  return static_cast<copy_options>(static_cast<unsigned short>(_LHS) &
                                   static_cast<unsigned short>(_RHS));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr copy_options operator|(copy_options _LHS, copy_options _RHS) {
  return static_cast<copy_options>(static_cast<unsigned short>(_LHS) |
                                   static_cast<unsigned short>(_RHS));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr copy_options operator^(copy_options _LHS, copy_options _RHS) {
  return static_cast<copy_options>(static_cast<unsigned short>(_LHS) ^
                                   static_cast<unsigned short>(_RHS));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr copy_options operator~(copy_options _LHS) {
  return static_cast<copy_options>(~static_cast<unsigned short>(_LHS));
}

_LIBCPP_INLINE_VISIBILITY
inline copy_options& operator&=(copy_options& _LHS, copy_options _RHS) {
  return _LHS = _LHS & _RHS;
}

_LIBCPP_INLINE_VISIBILITY
inline copy_options& operator|=(copy_options& _LHS, copy_options _RHS) {
  return _LHS = _LHS | _RHS;
}

_LIBCPP_INLINE_VISIBILITY
inline copy_options& operator^=(copy_options& _LHS, copy_options _RHS) {
  return _LHS = _LHS ^ _RHS;
}

_LIBCPP_AVAILABILITY_FILESYSTEM_POP

_LIBCPP_END_NAMESPACE_FILESYSTEM

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___FILESYSTEM_COPY_OPTIONS_H
