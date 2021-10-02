// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_VIEW_INTERFACE_H
#define _LIBCPP___RANGES_VIEW_INTERFACE_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/prev.h>
#include <__memory/pointer_traits.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/empty.h>
#include <__ranges/enable_view.h>
#include <concepts>
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
concept __can_empty = requires(_Tp __t) { ranges::empty(__t); };

template<class _Tp>
void __implicitly_convert_to(type_identity_t<_Tp>) noexcept;

template<class _Derived>
  requires is_class_v<_Derived> && same_as<_Derived, remove_cv_t<_Derived>>
class view_interface : public view_base {
  _LIBCPP_HIDE_FROM_ABI
  constexpr _Derived& __derived() noexcept {
    return static_cast<_Derived&>(*this);
  }

  _LIBCPP_HIDE_FROM_ABI
  constexpr _Derived const& __derived() const noexcept {
    return static_cast<_Derived const&>(*this);
  }

public:
  template<class _D2 = _Derived>
  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr bool empty()
    noexcept(noexcept(__implicitly_convert_to<bool>(ranges::begin(__derived()) == ranges::end(__derived()))))
    requires forward_range<_D2>
  {
    return ranges::begin(__derived()) == ranges::end(__derived());
  }

  template<class _D2 = _Derived>
  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr bool empty() const
    noexcept(noexcept(__implicitly_convert_to<bool>(ranges::begin(__derived()) == ranges::end(__derived()))))
    requires forward_range<const _D2>
  {
    return ranges::begin(__derived()) == ranges::end(__derived());
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr explicit operator bool()
    noexcept(noexcept(ranges::empty(declval<_D2>())))
    requires __can_empty<_D2>
  {
    return !ranges::empty(__derived());
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr explicit operator bool() const
    noexcept(noexcept(ranges::empty(declval<const _D2>())))
    requires __can_empty<const _D2>
  {
    return !ranges::empty(__derived());
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr auto data()
    noexcept(noexcept(_VSTD::to_address(ranges::begin(__derived()))))
    requires contiguous_iterator<iterator_t<_D2>>
  {
    return _VSTD::to_address(ranges::begin(__derived()));
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr auto data() const
    noexcept(noexcept(_VSTD::to_address(ranges::begin(__derived()))))
    requires range<const _D2> && contiguous_iterator<iterator_t<const _D2>>
  {
    return _VSTD::to_address(ranges::begin(__derived()));
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr auto size()
    noexcept(noexcept(ranges::end(__derived()) - ranges::begin(__derived())))
    requires forward_range<_D2>
      && sized_sentinel_for<sentinel_t<_D2>, iterator_t<_D2>>
  {
    return ranges::end(__derived()) - ranges::begin(__derived());
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr auto size() const
    noexcept(noexcept(ranges::end(__derived()) - ranges::begin(__derived())))
    requires forward_range<const _D2>
      && sized_sentinel_for<sentinel_t<const _D2>, iterator_t<const _D2>>
  {
    return ranges::end(__derived()) - ranges::begin(__derived());
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr decltype(auto) front()
    noexcept(noexcept(*ranges::begin(__derived())))
    requires forward_range<_D2>
  {
    _LIBCPP_ASSERT(!empty(),
        "Precondition `!empty()` not satisfied. `.front()` called on an empty view.");
    return *ranges::begin(__derived());
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr decltype(auto) front() const
    noexcept(noexcept(*ranges::begin(__derived())))
    requires forward_range<const _D2>
  {
    _LIBCPP_ASSERT(!empty(),
        "Precondition `!empty()` not satisfied. `.front()` called on an empty view.");
    return *ranges::begin(__derived());
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr decltype(auto) back()
    noexcept(noexcept(*ranges::prev(ranges::end(__derived()))))
    requires bidirectional_range<_D2> && common_range<_D2>
  {
    _LIBCPP_ASSERT(!empty(),
        "Precondition `!empty()` not satisfied. `.back()` called on an empty view.");
    return *ranges::prev(ranges::end(__derived()));
  }

  template<class _D2 = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr decltype(auto) back() const
    noexcept(noexcept(*ranges::prev(ranges::end(__derived()))))
    requires bidirectional_range<const _D2> && common_range<const _D2>
  {
    _LIBCPP_ASSERT(!empty(),
        "Precondition `!empty()` not satisfied. `.back()` called on an empty view.");
    return *ranges::prev(ranges::end(__derived()));
  }

  template<random_access_range _RARange = _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr decltype(auto) operator[](range_difference_t<_RARange> __index)
    noexcept(noexcept(ranges::begin(__derived())[__index]))
  {
    return ranges::begin(__derived())[__index];
  }

  template<random_access_range _RARange = const _Derived>
  _LIBCPP_HIDE_FROM_ABI
  constexpr decltype(auto) operator[](range_difference_t<_RARange> __index) const
    noexcept(noexcept(ranges::begin(__derived())[__index]))
  {
    return ranges::begin(__derived())[__index];
  }
};

}

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_VIEW_INTERFACE_H
