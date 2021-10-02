// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_NON_PROPAGATING_CACHE_H
#define _LIBCPP___RANGES_NON_PROPAGATING_CACHE_H

#include <__config>
#include <__iterator/concepts.h>        // indirectly_readable
#include <__iterator/iterator_traits.h> // iter_reference_t
#include <__memory/addressof.h>
#include <concepts>                     // constructible_from
#include <optional>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

// clang-format off

#if !defined(_LIBCPP_HAS_NO_RANGES)

namespace ranges {
  // __non_propagating_cache is a helper type that allows storing an optional value in it,
  // but which does not copy the source's value when it is copy constructed/assigned to,
  // and which resets the source's value when it is moved-from.
  //
  // This type is used as an implementation detail of some views that need to cache the
  // result of `begin()` in order to provide an amortized O(1) begin() method. Typically,
  // we don't want to propagate the value of the cache upon copy because the cached iterator
  // may refer to internal details of the source view.
  template<class _Tp>
    requires is_object_v<_Tp>
  class _LIBCPP_TEMPLATE_VIS __non_propagating_cache {
    optional<_Tp> __value_ = nullopt;

  public:
    _LIBCPP_HIDE_FROM_ABI __non_propagating_cache() = default;

    _LIBCPP_HIDE_FROM_ABI
    constexpr __non_propagating_cache(__non_propagating_cache const&) noexcept
      : __value_(nullopt)
    { }

    _LIBCPP_HIDE_FROM_ABI
    constexpr __non_propagating_cache(__non_propagating_cache&& __other) noexcept
      : __value_(nullopt)
    {
      __other.__value_.reset();
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr __non_propagating_cache& operator=(__non_propagating_cache const& __other) noexcept {
      if (this != _VSTD::addressof(__other)) {
        __value_.reset();
      }
      return *this;
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr __non_propagating_cache& operator=(__non_propagating_cache&& __other) noexcept {
      __value_.reset();
      __other.__value_.reset();
      return *this;
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr _Tp& operator*() { return *__value_; }
    _LIBCPP_HIDE_FROM_ABI
    constexpr _Tp const& operator*() const { return *__value_; }

    _LIBCPP_HIDE_FROM_ABI
    constexpr bool __has_value() const { return __value_.has_value(); }
    _LIBCPP_HIDE_FROM_ABI
    constexpr void __set(_Tp const& __value) { __value_.emplace(__value); }
    _LIBCPP_HIDE_FROM_ABI
    constexpr void __set(_Tp&& __value) { __value_.emplace(_VSTD::move(__value)); }
  };

  struct __empty_cache { };
} // namespace ranges

#endif // _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_NON_PROPAGATING_CACHE_H
