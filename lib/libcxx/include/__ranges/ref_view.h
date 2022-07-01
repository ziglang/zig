// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_REF_VIEW_H
#define _LIBCPP___RANGES_REF_VIEW_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iterator_traits.h>
#include <__memory/addressof.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/data.h>
#include <__ranges/empty.h>
#include <__ranges/enable_borrowed_range.h>
#include <__ranges/size.h>
#include <__ranges/view_interface.h>
#include <__utility/forward.h>
#include <concepts>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

namespace ranges {
  template<range _Range>
    requires is_object_v<_Range>
  class ref_view : public view_interface<ref_view<_Range>> {
    _Range *__range_;

    static void __fun(_Range&);
    static void __fun(_Range&&) = delete;

public:
    template<class _Tp>
      requires __different_from<_Tp, ref_view> &&
        convertible_to<_Tp, _Range&> && requires { __fun(declval<_Tp>()); }
    _LIBCPP_HIDE_FROM_ABI
    constexpr ref_view(_Tp&& __t)
      : __range_(_VSTD::addressof(static_cast<_Range&>(_VSTD::forward<_Tp>(__t))))
    {}

    _LIBCPP_HIDE_FROM_ABI constexpr _Range& base() const { return *__range_; }

    _LIBCPP_HIDE_FROM_ABI constexpr iterator_t<_Range> begin() const { return ranges::begin(*__range_); }
    _LIBCPP_HIDE_FROM_ABI constexpr sentinel_t<_Range> end() const { return ranges::end(*__range_); }

    _LIBCPP_HIDE_FROM_ABI
    constexpr bool empty() const
      requires requires { ranges::empty(*__range_); }
    { return ranges::empty(*__range_); }

    _LIBCPP_HIDE_FROM_ABI
    constexpr auto size() const
      requires sized_range<_Range>
    { return ranges::size(*__range_); }

    _LIBCPP_HIDE_FROM_ABI
    constexpr auto data() const
      requires contiguous_range<_Range>
    { return ranges::data(*__range_); }
  };

  template<class _Range>
  ref_view(_Range&) -> ref_view<_Range>;

  template<class _Tp>
  inline constexpr bool enable_borrowed_range<ref_view<_Tp>> = true;
} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___RANGES_REF_VIEW_H
