// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___RANGES_COPYABLE_BOX_H
#define _LIBCPP___RANGES_COPYABLE_BOX_H

#include <__config>
#include <__memory/addressof.h>
#include <__memory/construct_at.h>
#include <__utility/move.h>
#include <concepts>
#include <optional>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

// __copyable_box allows turning a type that is copy-constructible (but maybe not copy-assignable) into
// a type that is both copy-constructible and copy-assignable. It does that by introducing an empty state
// and basically doing destroy-then-copy-construct in the assignment operator. The empty state is necessary
// to handle the case where the copy construction fails after destroying the object.
//
// In some cases, we can completely avoid the use of an empty state; we provide a specialization of
// __copyable_box that does this, see below for the details.

template<class _Tp>
concept __copy_constructible_object = copy_constructible<_Tp> && is_object_v<_Tp>;

namespace ranges {
  // Primary template - uses std::optional and introduces an empty state in case assignment fails.
  template<__copy_constructible_object _Tp>
  class __copyable_box {
    _LIBCPP_NO_UNIQUE_ADDRESS optional<_Tp> __val_;

  public:
    template<class ..._Args>
      requires is_constructible_v<_Tp, _Args...>
    _LIBCPP_HIDE_FROM_ABI
    constexpr explicit __copyable_box(in_place_t, _Args&& ...__args)
      noexcept(is_nothrow_constructible_v<_Tp, _Args...>)
      : __val_(in_place, std::forward<_Args>(__args)...)
    { }

    _LIBCPP_HIDE_FROM_ABI
    constexpr __copyable_box() noexcept(is_nothrow_default_constructible_v<_Tp>)
      requires default_initializable<_Tp>
      : __val_(in_place)
    { }

    _LIBCPP_HIDE_FROM_ABI __copyable_box(__copyable_box const&) = default;
    _LIBCPP_HIDE_FROM_ABI __copyable_box(__copyable_box&&) = default;

    _LIBCPP_HIDE_FROM_ABI
    constexpr __copyable_box& operator=(__copyable_box const& __other)
      noexcept(is_nothrow_copy_constructible_v<_Tp>)
    {
      if (this != std::addressof(__other)) {
        if (__other.__has_value()) __val_.emplace(*__other);
        else                       __val_.reset();
      }
      return *this;
    }

    _LIBCPP_HIDE_FROM_ABI
    __copyable_box& operator=(__copyable_box&&) requires movable<_Tp> = default;

    _LIBCPP_HIDE_FROM_ABI
    constexpr __copyable_box& operator=(__copyable_box&& __other)
      noexcept(is_nothrow_move_constructible_v<_Tp>)
    {
      if (this != std::addressof(__other)) {
        if (__other.__has_value()) __val_.emplace(std::move(*__other));
        else                       __val_.reset();
      }
      return *this;
    }

    _LIBCPP_HIDE_FROM_ABI constexpr _Tp const& operator*() const noexcept { return *__val_; }
    _LIBCPP_HIDE_FROM_ABI constexpr _Tp& operator*() noexcept { return *__val_; }

    _LIBCPP_HIDE_FROM_ABI constexpr const _Tp *operator->() const noexcept { return __val_.operator->(); }
    _LIBCPP_HIDE_FROM_ABI constexpr _Tp *operator->() noexcept { return __val_.operator->(); }

    _LIBCPP_HIDE_FROM_ABI constexpr bool __has_value() const noexcept { return __val_.has_value(); }
  };

  // This partial specialization implements an optimization for when we know we don't need to store
  // an empty state to represent failure to perform an assignment. For copy-assignment, this happens:
  //
  // 1. If the type is copyable (which includes copy-assignment), we can use the type's own assignment operator
  //    directly and avoid using std::optional.
  // 2. If the type is not copyable, but it is nothrow-copy-constructible, then we can implement assignment as
  //    destroy-and-then-construct and we know it will never fail, so we don't need an empty state.
  //
  // The exact same reasoning can be applied for move-assignment, with copyable replaced by movable and
  // nothrow-copy-constructible replaced by nothrow-move-constructible. This specialization is enabled
  // whenever we can apply any of these optimizations for both the copy assignment and the move assignment
  // operator.
  template<class _Tp>
  concept __doesnt_need_empty_state_for_copy = copyable<_Tp> || is_nothrow_copy_constructible_v<_Tp>;

  template<class _Tp>
  concept __doesnt_need_empty_state_for_move = movable<_Tp> || is_nothrow_move_constructible_v<_Tp>;

  template<__copy_constructible_object _Tp>
    requires __doesnt_need_empty_state_for_copy<_Tp> && __doesnt_need_empty_state_for_move<_Tp>
  class __copyable_box<_Tp> {
    _LIBCPP_NO_UNIQUE_ADDRESS _Tp __val_;

  public:
    template<class ..._Args>
      requires is_constructible_v<_Tp, _Args...>
    _LIBCPP_HIDE_FROM_ABI
    constexpr explicit __copyable_box(in_place_t, _Args&& ...__args)
      noexcept(is_nothrow_constructible_v<_Tp, _Args...>)
      : __val_(std::forward<_Args>(__args)...)
    { }

    _LIBCPP_HIDE_FROM_ABI
    constexpr __copyable_box() noexcept(is_nothrow_default_constructible_v<_Tp>)
      requires default_initializable<_Tp>
      : __val_()
    { }

    _LIBCPP_HIDE_FROM_ABI __copyable_box(__copyable_box const&) = default;
    _LIBCPP_HIDE_FROM_ABI __copyable_box(__copyable_box&&) = default;

    // Implementation of assignment operators in case we perform optimization (1)
    _LIBCPP_HIDE_FROM_ABI __copyable_box& operator=(__copyable_box const&) requires copyable<_Tp> = default;
    _LIBCPP_HIDE_FROM_ABI __copyable_box& operator=(__copyable_box&&) requires movable<_Tp> = default;

    // Implementation of assignment operators in case we perform optimization (2)
    _LIBCPP_HIDE_FROM_ABI
    constexpr __copyable_box& operator=(__copyable_box const& __other) noexcept {
      static_assert(is_nothrow_copy_constructible_v<_Tp>);
      if (this != std::addressof(__other)) {
        std::destroy_at(std::addressof(__val_));
        std::construct_at(std::addressof(__val_), __other.__val_);
      }
      return *this;
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr __copyable_box& operator=(__copyable_box&& __other) noexcept {
      static_assert(is_nothrow_move_constructible_v<_Tp>);
      if (this != std::addressof(__other)) {
        std::destroy_at(std::addressof(__val_));
        std::construct_at(std::addressof(__val_), std::move(__other.__val_));
      }
      return *this;
    }

    _LIBCPP_HIDE_FROM_ABI constexpr _Tp const& operator*() const noexcept { return __val_; }
    _LIBCPP_HIDE_FROM_ABI constexpr _Tp& operator*() noexcept { return __val_; }

    _LIBCPP_HIDE_FROM_ABI constexpr const _Tp *operator->() const noexcept { return std::addressof(__val_); }
    _LIBCPP_HIDE_FROM_ABI constexpr _Tp *operator->() noexcept { return std::addressof(__val_); }

    _LIBCPP_HIDE_FROM_ABI constexpr bool __has_value() const noexcept { return true; }
  };
} // namespace ranges

#endif // _LIBCPP_STD_VER > 17 && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___RANGES_COPYABLE_BOX_H
