// -*- C++ -*-
//===------------------------ __ranges/data.h ------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_DATA_H
#define _LIBCPP___RANGES_DATA_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/iterator_traits.h>
#include <__memory/pointer_traits.h>
#include <__ranges/access.h>
#include <__utility/forward.h>
#include <concepts>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_RANGES)

// clang-format off
namespace ranges {
// [range.prim.data]
namespace __data {
  template <class _Tp>
  concept __ptr_to_object = is_pointer_v<_Tp> && is_object_v<remove_pointer_t<_Tp>>;

  template <class _Tp>
  concept __member_data =
    requires(_Tp&& __t) {
      { _VSTD::forward<_Tp>(__t) } -> __can_borrow;
      { __t.data() } -> __ptr_to_object;
    };

  template <class _Tp>
  concept __ranges_begin_invocable =
    !__member_data<_Tp> &&
    requires(_Tp&& __t) {
      { _VSTD::forward<_Tp>(__t) } -> __can_borrow;
      { ranges::begin(_VSTD::forward<_Tp>(__t)) } -> contiguous_iterator;
    };

  struct __fn {
    template <__member_data _Tp>
      requires __can_borrow<_Tp>
    _LIBCPP_HIDE_FROM_ABI
    constexpr __ptr_to_object auto operator()(_Tp&& __t) const
        noexcept(noexcept(__t.data())) {
      return __t.data();
    }

    template<__ranges_begin_invocable _Tp>
      requires __can_borrow<_Tp>
    _LIBCPP_HIDE_FROM_ABI
    constexpr __ptr_to_object auto operator()(_Tp&& __t) const
        noexcept(noexcept(_VSTD::to_address(ranges::begin(_VSTD::forward<_Tp>(__t))))) {
      return _VSTD::to_address(ranges::begin(_VSTD::forward<_Tp>(__t)));
    }
  };
} // end namespace __data

inline namespace __cpo {
  inline constexpr const auto data = __data::__fn{};
} // namespace __cpo
} // namespace ranges

// clang-format off

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_DATA_H
