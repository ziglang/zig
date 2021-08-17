// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_EMPTY_VIEW_H
#define _LIBCPP___RANGES_EMPTY_VIEW_H

#include <__config>
#include <__ranges/view_interface.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_RANGES)

namespace ranges {
  template<class _Tp>
    requires is_object_v<_Tp>
  class empty_view : public view_interface<empty_view<_Tp>> {
  public:
    _LIBCPP_HIDE_FROM_ABI static constexpr _Tp* begin() noexcept { return nullptr; }
    _LIBCPP_HIDE_FROM_ABI static constexpr _Tp* end() noexcept { return nullptr; }
    _LIBCPP_HIDE_FROM_ABI static constexpr _Tp* data() noexcept { return nullptr; }
    _LIBCPP_HIDE_FROM_ABI static constexpr size_t size() noexcept { return 0; }
    _LIBCPP_HIDE_FROM_ABI static constexpr bool empty() noexcept { return true; }
  };
} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_EMPTY_VIEW_H
