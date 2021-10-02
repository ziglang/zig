// -*- C++ -*-
//===------------------------ __ranges/access.h ---------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_ACCESS_H
#define _LIBCPP___RANGES_ACCESS_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/readable_traits.h>
#include <__ranges/enable_borrowed_range.h>
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
  template <class _Tp>
  concept __can_borrow =
      is_lvalue_reference_v<_Tp> || enable_borrowed_range<remove_cvref_t<_Tp> >;

  template<class _Tp>
  concept __is_complete = requires { sizeof(_Tp); };
} // namespace ranges

// [range.access.begin]
namespace ranges::__begin {
  template <class _Tp>
  concept __member_begin =
    __can_borrow<_Tp> &&
    requires(_Tp&& __t) {
      { _VSTD::__decay_copy(__t.begin()) } -> input_or_output_iterator;
    };

  void begin(auto&) = delete;
  void begin(const auto&) = delete;

  template <class _Tp>
  concept __unqualified_begin =
    !__member_begin<_Tp> &&
    __can_borrow<_Tp> &&
    __class_or_enum<remove_cvref_t<_Tp> > &&
    requires(_Tp && __t) {
      { _VSTD::__decay_copy(begin(__t)) } -> input_or_output_iterator;
    };

  struct __fn {
    template <class _Tp>
    requires is_array_v<remove_cv_t<_Tp>>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp& __t) const noexcept {
      constexpr bool __complete = __is_complete<iter_value_t<_Tp> >;
      if constexpr (__complete) { // used to disable cryptic diagnostic
        return __t + 0;
      }
      else {
        static_assert(__complete, "`std::ranges::begin` is SFINAE-unfriendly on arrays of an incomplete type.");
      }
    }

    template <class _Tp>
    requires __member_begin<_Tp>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp&& __t) const
    noexcept(noexcept(_VSTD::__decay_copy(__t.begin())))
    {
      return __t.begin();
    }

    template <class _Tp>
    requires __unqualified_begin<_Tp>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp&& __t) const
    noexcept(noexcept(_VSTD::__decay_copy(begin(__t))))
    {
      return begin(__t);
    }

    void operator()(auto&&) const = delete;
  };
} // namespace ranges::__begin

namespace ranges {
  inline namespace __cpo {
    inline constexpr auto begin = __begin::__fn{};
  } // namespace __cpo

  template <class _Tp>
  using iterator_t = decltype(ranges::begin(declval<_Tp&>()));
} // namespace ranges

// [range.access.end]
namespace ranges::__end {
  template <class _Tp>
  concept __member_end =
    __can_borrow<_Tp> &&
    requires(_Tp&& __t) {
      typename iterator_t<_Tp>;
      { _VSTD::__decay_copy(_VSTD::forward<_Tp>(__t).end()) } -> sentinel_for<iterator_t<_Tp> >;
    };

  void end(auto&) = delete;
  void end(const auto&) = delete;

  template <class _Tp>
  concept __unqualified_end =
    !__member_end<_Tp> &&
    __can_borrow<_Tp> &&
    __class_or_enum<remove_cvref_t<_Tp> > &&
    requires(_Tp && __t) {
      typename iterator_t<_Tp>;
      { _VSTD::__decay_copy(end(_VSTD::forward<_Tp>(__t))) } -> sentinel_for<iterator_t<_Tp> >;
    };

  class __fn {
  public:
    template <class _Tp, size_t _Np>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp (&__t)[_Np]) const noexcept {
      constexpr bool __complete = __is_complete<remove_cv_t<_Tp> >;
      if constexpr (__complete) { // used to disable cryptic diagnostic
        return __t + _Np;
      }
      else {
        static_assert(__complete, "`std::ranges::end` is SFINAE-unfriendly on arrays of an incomplete type.");
      }
    }

    template <class _Tp>
    requires __member_end<_Tp>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp&& __t) const
    noexcept(noexcept(_VSTD::__decay_copy(__t.end())))
    {
      return _VSTD::forward<_Tp>(__t).end();
    }

    template <class _Tp>
    requires __unqualified_end<_Tp>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp&& __t) const
    noexcept(noexcept(_VSTD::__decay_copy(end(__t))))
    {
      return end(__t);
    }

    void operator()(auto&&) const = delete;
  };
} // namespace ranges::__end

namespace ranges::inline __cpo {
  inline constexpr auto end = __end::__fn{};
} // namespace ranges::__cpo

namespace ranges::__cbegin {
  struct __fn {
    template <class _Tp>
    requires invocable<decltype(ranges::begin), _Tp const&>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp& __t) const
    noexcept(noexcept(ranges::begin(_VSTD::as_const(__t))))
    {
      return ranges::begin(_VSTD::as_const(__t));
    }

    template <class _Tp>
    requires is_rvalue_reference_v<_Tp> && invocable<decltype(ranges::begin), _Tp const&&>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp&& __t) const
    noexcept(noexcept(ranges::begin(static_cast<_Tp const&&>(__t))))
    {
      return ranges::begin(static_cast<_Tp const&&>(__t));
    }
  };
} // namespace ranges::__cbegin

namespace ranges::inline __cpo {
  inline constexpr auto cbegin = __cbegin::__fn{};
} // namespace ranges::__cpo

namespace ranges::__cend {
  struct __fn {
    template <class _Tp>
    requires invocable<decltype(ranges::end), _Tp const&>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp& __t) const
    noexcept(noexcept(ranges::end(_VSTD::as_const(__t))))
    {
      return ranges::end(_VSTD::as_const(__t));
    }

    template <class _Tp>
    requires is_rvalue_reference_v<_Tp> && invocable<decltype(ranges::end), _Tp const&&>
    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Tp&& __t) const
    noexcept(noexcept(ranges::end(static_cast<_Tp const&&>(__t))))
    {
      return ranges::end(static_cast<_Tp const&&>(__t));
    }
  };
} // namespace ranges::__cend

namespace ranges::inline __cpo {
  inline constexpr auto cend = __cend::__fn{};
} // namespace ranges::__cpo

// clang-format off

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_ACCESS_H
