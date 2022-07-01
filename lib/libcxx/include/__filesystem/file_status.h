// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FILESYSTEM_FILE_STATUS_H
#define _LIBCPP___FILESYSTEM_FILE_STATUS_H

#include <__availability>
#include <__config>
#include <__filesystem/file_type.h>
#include <__filesystem/perms.h>

#ifndef _LIBCPP_CXX03_LANG

_LIBCPP_BEGIN_NAMESPACE_FILESYSTEM

_LIBCPP_AVAILABILITY_FILESYSTEM_PUSH

class _LIBCPP_TYPE_VIS file_status {
public:
  // constructors
  _LIBCPP_INLINE_VISIBILITY
  file_status() noexcept : file_status(file_type::none) {}
  _LIBCPP_INLINE_VISIBILITY
  explicit file_status(file_type __ft, perms __prms = perms::unknown) noexcept
      : __ft_(__ft),
        __prms_(__prms) {}

  file_status(const file_status&) noexcept = default;
  file_status(file_status&&) noexcept = default;

  _LIBCPP_INLINE_VISIBILITY
  ~file_status() {}

  file_status& operator=(const file_status&) noexcept = default;
  file_status& operator=(file_status&&) noexcept = default;

  // observers
  _LIBCPP_INLINE_VISIBILITY
  file_type type() const noexcept { return __ft_; }

  _LIBCPP_INLINE_VISIBILITY
  perms permissions() const noexcept { return __prms_; }

  // modifiers
  _LIBCPP_INLINE_VISIBILITY
  void type(file_type __ft) noexcept { __ft_ = __ft; }

  _LIBCPP_INLINE_VISIBILITY
  void permissions(perms __p) noexcept { __prms_ = __p; }

private:
  file_type __ft_;
  perms __prms_;
};

_LIBCPP_AVAILABILITY_FILESYSTEM_POP

_LIBCPP_END_NAMESPACE_FILESYSTEM

#endif // _LIBCPP_CXX03_LANG

#endif // _LIBCPP___FILESYSTEM_FILE_STATUS_H
