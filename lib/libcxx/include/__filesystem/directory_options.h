// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FILESYSTEM_DIRECTORY_OPTIONS_H
#define _LIBCPP___FILESYSTEM_DIRECTORY_OPTIONS_H

#include <__availability>
#include <__config>

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

_LIBCPP_AVAILABILITY_FILESYSTEM_PUSH

enum class _LIBCPP_ENUM_VIS directory_options : unsigned char {
  none = 0,
  follow_directory_symlink = 1,
  skip_permission_denied = 2
};

_LIBCPP_INLINE_VISIBILITY
inline constexpr directory_options operator&(directory_options _LHS,
                                             directory_options _RHS) {
  return static_cast<directory_options>(static_cast<unsigned char>(_LHS) &
                                        static_cast<unsigned char>(_RHS));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr directory_options operator|(directory_options _LHS,
                                             directory_options _RHS) {
  return static_cast<directory_options>(static_cast<unsigned char>(_LHS) |
                                        static_cast<unsigned char>(_RHS));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr directory_options operator^(directory_options _LHS,
                                             directory_options _RHS) {
  return static_cast<directory_options>(static_cast<unsigned char>(_LHS) ^
                                        static_cast<unsigned char>(_RHS));
}

_LIBCPP_INLINE_VISIBILITY
inline constexpr directory_options operator~(directory_options _LHS) {
  return static_cast<directory_options>(~static_cast<unsigned char>(_LHS));
}

_LIBCPP_INLINE_VISIBILITY
inline directory_options& operator&=(directory_options& _LHS,
                                     directory_options _RHS) {
  return _LHS = _LHS & _RHS;
}

_LIBCPP_INLINE_VISIBILITY
inline directory_options& operator|=(directory_options& _LHS,
                                     directory_options _RHS) {
  return _LHS = _LHS | _RHS;
}

_LIBCPP_INLINE_VISIBILITY
inline directory_options& operator^=(directory_options& _LHS,
                                     directory_options _RHS) {
  return _LHS = _LHS ^ _RHS;
}

_LIBCPP_AVAILABILITY_FILESYSTEM_POP

_LIBCPP_END_NAMESPACE_FILESYSTEM

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___FILESYSTEM_DIRECTORY_OPTIONS_H
