// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_TAKE_VIEW_H
#define _LIBCPP___RANGES_TAKE_VIEW_H

#include <__algorithm/min.h>
#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/counted_iterator.h>
#include <__iterator/default_sentinel.h>
#include <__iterator/iterator_traits.h>
#include <__ranges/access.h>
#include <__ranges/all.h>
#include <__ranges/concepts.h>
#include <__ranges/enable_borrowed_range.h>
#include <__ranges/size.h>
#include <__ranges/view_interface.h>
#include <__utility/move.h>
#include <concepts>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

namespace ranges {
  template<view _View>
  class take_view : public view_interface<take_view<_View>> {
    [[no_unique_address]] _View __base_ = _View();
    range_difference_t<_View> __count_ = 0;

    template<bool> class __sentinel;

  public:
    _LIBCPP_HIDE_FROM_ABI
    take_view() requires default_initializable<_View> = default;

    _LIBCPP_HIDE_FROM_ABI
    constexpr take_view(_View __base, range_difference_t<_View> __count)
      : __base_(_VSTD::move(__base)), __count_(__count) {}

    _LIBCPP_HIDE_FROM_ABI
    constexpr _View base() const& requires copy_constructible<_View> { return __base_; }

    _LIBCPP_HIDE_FROM_ABI
    constexpr _View base() && { return _VSTD::move(__base_); }

    _LIBCPP_HIDE_FROM_ABI
    constexpr auto begin() requires (!__simple_view<_View>) {
      if constexpr (sized_range<_View>) {
        if constexpr (random_access_range<_View>) {
          return ranges::begin(__base_);
        } else {
          using _DifferenceT = range_difference_t<_View>;
          auto __size = size();
          return counted_iterator(ranges::begin(__base_), static_cast<_DifferenceT>(__size));
        }
      } else {
        return counted_iterator(ranges::begin(__base_), __count_);
      }
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr auto begin() const requires range<const _View> {
      if constexpr (sized_range<const _View>) {
        if constexpr (random_access_range<const _View>) {
          return ranges::begin(__base_);
        } else {
          using _DifferenceT = range_difference_t<const _View>;
          auto __size = size();
          return counted_iterator(ranges::begin(__base_), static_cast<_DifferenceT>(__size));
        }
      } else {
        return counted_iterator(ranges::begin(__base_), __count_);
      }
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr auto end() requires (!__simple_view<_View>) {
      if constexpr (sized_range<_View>) {
        if constexpr (random_access_range<_View>) {
          return ranges::begin(__base_) + size();
        } else {
          return default_sentinel;
        }
      } else {
        return __sentinel<false>{ranges::end(__base_)};
      }
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr auto end() const requires range<const _View> {
      if constexpr (sized_range<const _View>) {
        if constexpr (random_access_range<const _View>) {
          return ranges::begin(__base_) + size();
        } else {
          return default_sentinel;
        }
      } else {
        return __sentinel<true>{ranges::end(__base_)};
      }
    }


    _LIBCPP_HIDE_FROM_ABI
    constexpr auto size() requires sized_range<_View> {
      auto __n = ranges::size(__base_);
      // TODO: use ranges::min here.
      return _VSTD::min(__n, static_cast<decltype(__n)>(__count_));
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr auto size() const requires sized_range<const _View> {
      auto __n = ranges::size(__base_);
      // TODO: use ranges::min here.
      return _VSTD::min(__n, static_cast<decltype(__n)>(__count_));
    }
  };

  template<view _View>
  template<bool _Const>
  class take_view<_View>::__sentinel {
    using _Base = __maybe_const<_Const, _View>;
    template<bool _OtherConst>
    using _Iter = counted_iterator<iterator_t<__maybe_const<_OtherConst, _View>>>;
    [[no_unique_address]] sentinel_t<_Base> __end_ = sentinel_t<_Base>();

    template<bool>
    friend class take_view<_View>::__sentinel;

public:
    _LIBCPP_HIDE_FROM_ABI
    __sentinel() = default;

    _LIBCPP_HIDE_FROM_ABI
    constexpr explicit __sentinel(sentinel_t<_Base> __end) : __end_(_VSTD::move(__end)) {}

    _LIBCPP_HIDE_FROM_ABI
    constexpr __sentinel(__sentinel<!_Const> __s)
      requires _Const && convertible_to<sentinel_t<_View>, sentinel_t<_Base>>
      : __end_(_VSTD::move(__s.__end_)) {}

    _LIBCPP_HIDE_FROM_ABI
    constexpr sentinel_t<_Base> base() const { return __end_; }

    _LIBCPP_HIDE_FROM_ABI
    friend constexpr bool operator==(const _Iter<_Const>& __lhs, const __sentinel& __rhs) {
      return __lhs.count() == 0 || __lhs.base() == __rhs.__end_;
    }

    template<bool _OtherConst = !_Const>
      requires sentinel_for<sentinel_t<_Base>, iterator_t<__maybe_const<_OtherConst, _View>>>
    _LIBCPP_HIDE_FROM_ABI
    friend constexpr bool operator==(const _Iter<_Const>& __lhs, const __sentinel& __rhs) {
      return __lhs.count() == 0 || __lhs.base() == __rhs.__end_;
    }
  };

  template<class _Range>
  take_view(_Range&&, range_difference_t<_Range>) -> take_view<views::all_t<_Range>>;

  template<class _Tp>
  inline constexpr bool enable_borrowed_range<take_view<_Tp>> = enable_borrowed_range<_Tp>;
} // namespace ranges

#endif // !defined(_LIBCPP_HAS_NO_CONCEPTS) && !defined(_LIBCPP_HAS_NO_INCOMPLETE_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_TAKE_VIEW_H
