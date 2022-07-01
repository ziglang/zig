// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___FORMAT_FORMAT_ARGS_H
#define _LIBCPP___FORMAT_FORMAT_ARGS_H

#include <__availability>
#include <__config>
#include <__format/format_fwd.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

// TODO FMT Remove this once we require compilers with proper C++20 support.
// If the compiler has no concepts support, the format header will be disabled.
// Without concepts support enable_if needs to be used and that too much effort
// to support compilers with partial C++20 support.
#if !defined(_LIBCPP_HAS_NO_CONCEPTS)

template <class _Context>
class _LIBCPP_TEMPLATE_VIS _LIBCPP_AVAILABILITY_FORMAT basic_format_args {
public:
  // TODO FMT Implement [format.args]/5
  // [Note 1: Implementations are encouraged to optimize the representation of
  // basic_format_args for small number of formatting arguments by storing
  // indices of type alternatives separately from values and packing the
  // former. - end note]
  // Note: Change  __format_arg_store to use a built-in array.
  _LIBCPP_HIDE_FROM_ABI basic_format_args() noexcept = default;

  template <class... _Args>
  _LIBCPP_HIDE_FROM_ABI basic_format_args(
      const __format_arg_store<_Context, _Args...>& __store) noexcept
      : __size_(sizeof...(_Args)), __data_(__store.__args.data()) {}

  _LIBCPP_HIDE_FROM_ABI
  basic_format_arg<_Context> get(size_t __id) const noexcept {
    return __id < __size_ ? __data_[__id] : basic_format_arg<_Context>{};
  }

  _LIBCPP_HIDE_FROM_ABI size_t __size() const noexcept { return __size_; }

private:
  size_t __size_{0};
  const basic_format_arg<_Context>* __data_{nullptr};
};

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS)

#endif //_LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___FORMAT_FORMAT_ARGS_H
