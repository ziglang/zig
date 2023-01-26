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
#include <__iterator/readable_traits.h>
#include <__memory/concepts.h>
#include <__memory/construct_at.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/dangling.h>
#include <__utility/declval.h>
#include <__utility/forward.h>
#include <__utility/move.h>
#include <new>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17
namespace ranges {

// construct_at

namespace __construct_at {

struct __fn {
  template<class _Tp, class... _Args, class = decltype(
    ::new (std::declval<void*>()) _Tp(std::declval<_Args>()...)
  )>
  _LIBCPP_HIDE_FROM_ABI
  constexpr _Tp* operator()(_Tp* __location, _Args&& ...__args) const {
    return _VSTD::construct_at(__location, _VSTD::forward<_Args>(__args)...);
  }
};

} // namespace __construct_at

inline namespace __cpo {
  inline constexpr auto construct_at = __construct_at::__fn{};
} // namespace __cpo

// destroy_at

namespace __destroy_at {

struct __fn {
  template <destructible _Tp>
  _LIBCPP_HIDE_FROM_ABI
  constexpr void operator()(_Tp* __location) const noexcept {
    _VSTD::destroy_at(__location);
  }
};

} // namespace __destroy_at

inline namespace __cpo {
  inline constexpr auto destroy_at = __destroy_at::__fn{};
} // namespace __cpo

// destroy

namespace __destroy {

struct __fn {
  template <__nothrow_input_iterator _InputIterator, __nothrow_sentinel_for<_InputIterator> _Sentinel>
    requires destructible<iter_value_t<_InputIterator>>
  _LIBCPP_HIDE_FROM_ABI
  constexpr _InputIterator operator()(_InputIterator __first, _Sentinel __last) const noexcept {
    return _VSTD::__destroy(_VSTD::move(__first), _VSTD::move(__last));
  }

  template <__nothrow_input_range _InputRange>
    requires destructible<range_value_t<_InputRange>>
  _LIBCPP_HIDE_FROM_ABI
  constexpr borrowed_iterator_t<_InputRange> operator()(_InputRange&& __range) const noexcept {
    return (*this)(ranges::begin(__range), ranges::end(__range));
  }
};

} // namespace __destroy

inline namespace __cpo {
  inline constexpr auto destroy = __destroy::__fn{};
} // namespace __cpo

// destroy_n

namespace __destroy_n {

struct __fn {
  template <__nothrow_input_iterator _InputIterator>
    requires destructible<iter_value_t<_InputIterator>>
  _LIBCPP_HIDE_FROM_ABI
  constexpr _InputIterator operator()(_InputIterator __first, iter_difference_t<_InputIterator> __n) const noexcept {
    return _VSTD::destroy_n(_VSTD::move(__first), __n);
  }
};

} // namespace __destroy_n

inline namespace __cpo {
  inline constexpr auto destroy_n = __destroy_n::__fn{};
} // namespace __cpo

} // namespace ranges

#endif // _LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___MEMORY_RANGES_CONSTRUCT_AT_H
