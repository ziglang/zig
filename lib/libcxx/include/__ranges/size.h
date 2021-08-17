// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_SIZE_H
#define _LIBCPP___RANGES_SIZE_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/iterator_traits.h>
#include <__ranges/access.h>
#include <__utility/__decay_copy.h>
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
template<class>
inline constexpr bool disable_sized_range = false;

// [range.prim.size]
namespace __size {
  void size(auto&) = delete;
  void size(const auto&) = delete;

  template <class _Tp>
  concept __size_enabled = !disable_sized_range<remove_cvref_t<_Tp>>;

  template <class _Tp>
  concept __member_size = __size_enabled<_Tp> && requires(_Tp&& __t) {
    { _VSTD::__decay_copy(_VSTD::forward<_Tp>(__t).size()) } -> __integer_like;
  };

  template <class _Tp>
  concept __unqualified_size =
    __size_enabled<_Tp> &&
    !__member_size<_Tp> &&
    __class_or_enum<remove_cvref_t<_Tp>> &&
    requires(_Tp&& __t) {
      { _VSTD::__decay_copy(size(_VSTD::forward<_Tp>(__t))) } -> __integer_like;
    };

  template <class _Tp>
  concept __difference =
    !__member_size<_Tp> &&
    !__unqualified_size<_Tp> &&
    __class_or_enum<remove_cvref_t<_Tp>> &&
    requires(_Tp&& __t) {
      { ranges::begin(__t) } -> forward_iterator;
      { ranges::end(__t) } -> sized_sentinel_for<decltype(ranges::begin(declval<_Tp>()))>;
    };

  struct __fn {
    template <class _Tp, size_t _Sz>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr size_t operator()(_Tp (&&)[_Sz]) const noexcept {
      return _Sz;
    }

    template <class _Tp, size_t _Sz>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr size_t operator()(_Tp (&)[_Sz]) const noexcept {
      return _Sz;
    }

    template <__member_size _Tp>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr __integer_like auto operator()(_Tp&& __t) const
        noexcept(noexcept(_VSTD::forward<_Tp>(__t).size())) {
      return _VSTD::forward<_Tp>(__t).size();
    }

    template <__unqualified_size _Tp>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr __integer_like auto operator()(_Tp&& __t) const
        noexcept(noexcept(size(_VSTD::forward<_Tp>(__t)))) {
      return size(_VSTD::forward<_Tp>(__t));
    }

    template<__difference _Tp>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr __integer_like auto operator()(_Tp&& __t) const
        noexcept(noexcept(ranges::end(__t) - ranges::begin(__t))) {
      return _VSTD::__to_unsigned_like(ranges::end(__t) - ranges::begin(__t));
    }
  };
} // end namespace __size

inline namespace __cpo {
  inline constexpr auto size = __size::__fn{};
} // namespace __cpo

namespace __ssize {
  struct __fn {
    template<class _Tp>
      requires requires (_Tp&& __t) { ranges::size(__t); }
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr integral auto operator()(_Tp&& __t) const
        noexcept(noexcept(ranges::size(__t))) {
      using _Signed = make_signed_t<decltype(ranges::size(__t))>;
      if constexpr (sizeof(ptrdiff_t) > sizeof(_Signed))
        return static_cast<ptrdiff_t>(ranges::size(__t));
      else
        return static_cast<_Signed>(ranges::size(__t));
    }
  };
}

inline namespace __cpo {
  inline constexpr const auto ssize = __ssize::__fn{};
} // namespace __cpo
} // namespace ranges

// clang-format off

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_SIZE_H
