// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___MEMORY_RANGES_CONSTRUCT_AT_H
#define _LIBCPP___MEMORY_RANGES_CONSTRUCT_AT_H

#include <__concepts/destructible.h>
#include <__config>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iterator_traits.h>
#include <__memory/concepts.h>
#include <__memory/construct_at.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/dangling.h>
#include <__utility/declval.h>
#include <__utility/forward.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 20
namespace ranges {

// construct_at

struct __construct_at {
  template <class _Tp, class... _Args, class = decltype(::new(std::declval<void*>()) _Tp(std::declval<_Args>()...))>
  _LIBCPP_HIDE_FROM_ABI constexpr _Tp* operator()(_Tp* __location, _Args&&... __args) const {
    return std::construct_at(__location, std::forward<_Args>(__args)...);
  }
};

inline namespace __cpo {
inline constexpr auto construct_at = __construct_at{};
} // namespace __cpo

// destroy_at

struct __destroy_at {
  template <destructible _Tp>
  _LIBCPP_HIDE_FROM_ABI constexpr void operator()(_Tp* __location) const noexcept {
    std::destroy_at(__location);
  }
};

inline namespace __cpo {
inline constexpr auto destroy_at = __destroy_at{};
} // namespace __cpo

// destroy

struct __destroy {
  template <__nothrow_input_iterator _InputIterator, __nothrow_sentinel_for<_InputIterator> _Sentinel>
    requires destructible<iter_value_t<_InputIterator>>
  _LIBCPP_HIDE_FROM_ABI constexpr _InputIterator operator()(_InputIterator __first, _Sentinel __last) const noexcept {
    return std::__destroy(std::move(__first), std::move(__last));
  }

  template <__nothrow_input_range _InputRange>
    requires destructible<range_value_t<_InputRange>>
  _LIBCPP_HIDE_FROM_ABI constexpr borrowed_iterator_t<_InputRange> operator()(_InputRange&& __range) const noexcept {
    return (*this)(ranges::begin(__range), ranges::end(__range));
  }
};

inline namespace __cpo {
inline constexpr auto destroy = __destroy{};
} // namespace __cpo

// destroy_n

struct __destroy_n {
  template <__nothrow_input_iterator _InputIterator>
    requires destructible<iter_value_t<_InputIterator>>
  _LIBCPP_HIDE_FROM_ABI constexpr _InputIterator
  operator()(_InputIterator __first, iter_difference_t<_InputIterator> __n) const noexcept {
    return std::destroy_n(std::move(__first), __n);
  }
};

inline namespace __cpo {
inline constexpr auto destroy_n = __destroy_n{};
} // namespace __cpo

} // namespace ranges

#endif // _LIBCPP_STD_VER >= 20

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___MEMORY_RANGES_CONSTRUCT_AT_H
