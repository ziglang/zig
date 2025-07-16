// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___RANGES_JOIN_WITH_VIEW_H
#define _LIBCPP___RANGES_JOIN_WITH_VIEW_H

#include <__concepts/common_reference_with.h>
#include <__concepts/common_with.h>
#include <__concepts/constructible.h>
#include <__concepts/convertible_to.h>
#include <__concepts/derived_from.h>
#include <__concepts/equality_comparable.h>
#include <__config>
#include <__functional/bind_back.h>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iter_move.h>
#include <__iterator/iter_swap.h>
#include <__iterator/iterator_traits.h>
#include <__memory/addressof.h>
#include <__ranges/access.h>
#include <__ranges/all.h>
#include <__ranges/concepts.h>
#include <__ranges/non_propagating_cache.h>
#include <__ranges/range_adaptor.h>
#include <__ranges/single_view.h>
#include <__ranges/view_interface.h>
#include <__type_traits/conditional.h>
#include <__type_traits/decay.h>
#include <__type_traits/is_reference.h>
#include <__type_traits/maybe_const.h>
#include <__utility/as_const.h>
#include <__utility/as_lvalue.h>
#include <__utility/empty.h>
#include <__utility/forward.h>
#include <__utility/move.h>
#include <variant>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 23

namespace ranges {
template <class _Range>
concept __bidirectional_common = bidirectional_range<_Range> && common_range<_Range>;

template <input_range _View, forward_range _Pattern>
  requires view<_View> && input_range<range_reference_t<_View>> && view<_Pattern> &&
           __concatable<range_reference_t<_View>, _Pattern>
class join_with_view : public view_interface<join_with_view<_View, _Pattern>> {
  using _InnerRng _LIBCPP_NODEBUG = range_reference_t<_View>;

  _LIBCPP_NO_UNIQUE_ADDRESS _View __base_ = _View();

  static constexpr bool _UseOuterItCache = !forward_range<_View>;
  using _OuterItCache _LIBCPP_NODEBUG =
      _If<_UseOuterItCache, __non_propagating_cache<iterator_t<_View>>, __empty_cache>;
  _LIBCPP_NO_UNIQUE_ADDRESS _OuterItCache __outer_it_;

  static constexpr bool _UseInnerCache = !is_reference_v<_InnerRng>;
  using _InnerCache _LIBCPP_NODEBUG =
      _If<_UseInnerCache, __non_propagating_cache<remove_cvref_t<_InnerRng>>, __empty_cache>;
  _LIBCPP_NO_UNIQUE_ADDRESS _InnerCache __inner_;

  _LIBCPP_NO_UNIQUE_ADDRESS _Pattern __pattern_ = _Pattern();

  template <bool _Const>
  struct __iterator;

  template <bool _Const>
  struct __sentinel;

public:
  _LIBCPP_HIDE_FROM_ABI join_with_view()
    requires default_initializable<_View> && default_initializable<_Pattern>
  = default;

  _LIBCPP_HIDE_FROM_ABI constexpr explicit join_with_view(_View __base, _Pattern __pattern)
      : __base_(std::move(__base)), __pattern_(std::move(__pattern)) {}

  template <input_range _Range>
    requires constructible_from<_View, views::all_t<_Range>> &&
                 constructible_from<_Pattern, single_view<range_value_t<_InnerRng>>>
  _LIBCPP_HIDE_FROM_ABI constexpr explicit join_with_view(_Range&& __r, range_value_t<_InnerRng> __e)
      : __base_(views::all(std::forward<_Range>(__r))), __pattern_(views::single(std::move(__e))) {}

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr _View base() const&
    requires copy_constructible<_View>
  {
    return __base_;
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr _View base() && { return std::move(__base_); }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto begin() {
    if constexpr (forward_range<_View>) {
      constexpr bool __use_const = __simple_view<_View> && is_reference_v<_InnerRng> && __simple_view<_Pattern>;
      return __iterator<__use_const>{*this, ranges::begin(__base_)};
    } else {
      __outer_it_.__emplace(ranges::begin(__base_));
      return __iterator<false>{*this};
    }
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto begin() const
    requires forward_range<const _View> && forward_range<const _Pattern> &&
             is_reference_v<range_reference_t<const _View>> && input_range<range_reference_t<const _View>> &&
             __concatable<range_reference_t<const _View>, const _Pattern>
  {
    return __iterator<true>{*this, ranges::begin(__base_)};
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto end() {
    constexpr bool __use_const = __simple_view<_View> && __simple_view<_Pattern>;
    if constexpr (forward_range<_View> && is_reference_v<_InnerRng> && forward_range<_InnerRng> &&
                  common_range<_View> && common_range<_InnerRng>)
      return __iterator<__use_const>{*this, ranges::end(__base_)};
    else
      return __sentinel<__use_const>{*this};
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto end() const
    requires forward_range<const _View> && forward_range<const _Pattern> &&
             is_reference_v<range_reference_t<const _View>> && input_range<range_reference_t<const _View>> &&
             __concatable<range_reference_t<const _View>, const _Pattern>
  {
    using _InnerConstRng = range_reference_t<const _View>;
    if constexpr (forward_range<_InnerConstRng> && common_range<const _View> && common_range<_InnerConstRng>)
      return __iterator<true>{*this, ranges::end(__base_)};
    else
      return __sentinel<true>{*this};
  }
};

template <class _Range, class _Pattern>
join_with_view(_Range&&, _Pattern&&) -> join_with_view<views::all_t<_Range>, views::all_t<_Pattern>>;

template <input_range _Range>
join_with_view(_Range&&, range_value_t<range_reference_t<_Range>>)
    -> join_with_view<views::all_t<_Range>, single_view<range_value_t<range_reference_t<_Range>>>>;

template <class _Base, class _PatternBase, class _InnerBase = range_reference_t<_Base>>
struct __join_with_view_iterator_category {};

template <class _Base, class _PatternBase, class _InnerBase>
  requires is_reference_v<_InnerBase> && forward_range<_Base> && forward_range<_InnerBase>
struct __join_with_view_iterator_category<_Base, _PatternBase, _InnerBase> {
private:
  static consteval auto __get_iterator_category() noexcept {
    using _OuterC   = iterator_traits<iterator_t<_Base>>::iterator_category;
    using _InnerC   = iterator_traits<iterator_t<_InnerBase>>::iterator_category;
    using _PatternC = iterator_traits<iterator_t<_PatternBase>>::iterator_category;

    if constexpr (!is_reference_v<common_reference_t<iter_reference_t<iterator_t<_InnerBase>>,
                                                     iter_reference_t<iterator_t<_PatternBase>>>>)
      return input_iterator_tag{};
    else if constexpr (derived_from<_OuterC, bidirectional_iterator_tag> &&
                       derived_from<_InnerC, bidirectional_iterator_tag> &&
                       derived_from<_PatternC, bidirectional_iterator_tag> && common_range<_InnerBase> &&
                       common_range<_PatternBase>)
      return bidirectional_iterator_tag{};
    else if constexpr (derived_from<_OuterC, forward_iterator_tag> && derived_from<_InnerC, forward_iterator_tag> &&
                       derived_from<_PatternC, forward_iterator_tag>)
      return forward_iterator_tag{};
    else
      return input_iterator_tag{};
  }

public:
  using iterator_category = decltype(__get_iterator_category());
};

template <input_range _View, forward_range _Pattern>
  requires view<_View> && input_range<range_reference_t<_View>> && view<_Pattern> &&
           __concatable<range_reference_t<_View>, _Pattern>
template <bool _Const>
struct join_with_view<_View, _Pattern>::__iterator
    : public __join_with_view_iterator_category<__maybe_const<_Const, _View>, __maybe_const<_Const, _Pattern>> {
private:
  friend join_with_view;

  using _Parent _LIBCPP_NODEBUG      = __maybe_const<_Const, join_with_view>;
  using _Base _LIBCPP_NODEBUG        = __maybe_const<_Const, _View>;
  using _InnerBase _LIBCPP_NODEBUG   = range_reference_t<_Base>;
  using _PatternBase _LIBCPP_NODEBUG = __maybe_const<_Const, _Pattern>;

  using _OuterIter _LIBCPP_NODEBUG   = iterator_t<_Base>;
  using _InnerIter _LIBCPP_NODEBUG   = iterator_t<_InnerBase>;
  using _PatternIter _LIBCPP_NODEBUG = iterator_t<_PatternBase>;

  static_assert(!_Const || forward_range<_Base>, "Const can only be true when Base models forward_range.");

  static constexpr bool __ref_is_glvalue = is_reference_v<_InnerBase>;

  _Parent* __parent_ = nullptr;

  static constexpr bool _OuterIterPresent              = forward_range<_Base>;
  using _OuterIterType _LIBCPP_NODEBUG                 = _If<_OuterIterPresent, _OuterIter, std::__empty>;
  _LIBCPP_NO_UNIQUE_ADDRESS _OuterIterType __outer_it_ = _OuterIterType();

  variant<_PatternIter, _InnerIter> __inner_it_;

  _LIBCPP_HIDE_FROM_ABI constexpr __iterator(_Parent& __parent, _OuterIter __outer)
    requires forward_range<_Base>
      : __parent_(std::addressof(__parent)), __outer_it_(std::move(__outer)) {
    if (__get_outer() != ranges::end(__parent_->__base_)) {
      __inner_it_.template emplace<1>(ranges::begin(__update_inner()));
      __satisfy();
    }
  }

  _LIBCPP_HIDE_FROM_ABI constexpr explicit __iterator(_Parent& __parent)
    requires(!forward_range<_Base>)
      : __parent_(std::addressof(__parent)) {
    if (__get_outer() != ranges::end(__parent_->__base_)) {
      __inner_it_.template emplace<1>(ranges::begin(__update_inner()));
      __satisfy();
    }
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr _OuterIter& __get_outer() {
    if constexpr (forward_range<_Base>)
      return __outer_it_;
    else
      return *__parent_->__outer_it_;
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr const _OuterIter& __get_outer() const {
    if constexpr (forward_range<_Base>)
      return __outer_it_;
    else
      return *__parent_->__outer_it_;
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto& __update_inner() {
    if constexpr (__ref_is_glvalue)
      return std::__as_lvalue(*__get_outer());
    else
      return __parent_->__inner_.__emplace_from([this]() -> decltype(auto) { return *__get_outer(); });
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto& __get_inner() {
    if constexpr (__ref_is_glvalue)
      return std::__as_lvalue(*__get_outer());
    else
      return *__parent_->__inner_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr void __satisfy() {
    while (true) {
      if (__inner_it_.index() == 0) {
        if (std::get<0>(__inner_it_) != ranges::end(__parent_->__pattern_))
          break;

        __inner_it_.template emplace<1>(ranges::begin(__update_inner()));
      } else {
        if (std::get<1>(__inner_it_) != ranges::end(__get_inner()))
          break;

        if (++__get_outer() == ranges::end(__parent_->__base_)) {
          if constexpr (__ref_is_glvalue)
            __inner_it_.template emplace<0>();

          break;
        }

        __inner_it_.template emplace<0>(ranges::begin(__parent_->__pattern_));
      }
    }
  }

  [[nodiscard]] static consteval auto __get_iterator_concept() noexcept {
    if constexpr (__ref_is_glvalue && bidirectional_range<_Base> && __bidirectional_common<_InnerBase> &&
                  __bidirectional_common<_PatternBase>)
      return bidirectional_iterator_tag{};
    else if constexpr (__ref_is_glvalue && forward_range<_Base> && forward_range<_InnerBase>)
      return forward_iterator_tag{};
    else
      return input_iterator_tag{};
  }

public:
  using iterator_concept = decltype(__get_iterator_concept());
  using value_type       = common_type_t<iter_value_t<_InnerIter>, iter_value_t<_PatternIter>>;
  using difference_type =
      common_type_t<iter_difference_t<_OuterIter>, iter_difference_t<_InnerIter>, iter_difference_t<_PatternIter>>;

  _LIBCPP_HIDE_FROM_ABI __iterator() = default;

  _LIBCPP_HIDE_FROM_ABI constexpr __iterator(__iterator<!_Const> __i)
    requires _Const && convertible_to<iterator_t<_View>, _OuterIter> &&
                 convertible_to<iterator_t<_InnerRng>, _InnerIter> && convertible_to<iterator_t<_Pattern>, _PatternIter>
      : __parent_(__i.__parent_), __outer_it_(std::move(__i.__outer_it_)) {
    if (__i.__inner_it_.index() == 0) {
      __inner_it_.template emplace<0>(std::get<0>(std::move(__i.__inner_it_)));
    } else {
      __inner_it_.template emplace<1>(std::get<1>(std::move(__i.__inner_it_)));
    }
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr decltype(auto) operator*() const {
    using __reference = common_reference_t<iter_reference_t<_InnerIter>, iter_reference_t<_PatternIter>>;
    return std::visit([](auto& __it) -> __reference { return *__it; }, __inner_it_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __iterator& operator++() {
    std::visit([](auto& __it) { ++__it; }, __inner_it_);
    __satisfy();
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr void operator++(int) { ++*this; }

  _LIBCPP_HIDE_FROM_ABI constexpr __iterator operator++(int)
    requires __ref_is_glvalue && forward_iterator<_OuterIter> && forward_iterator<_InnerIter>
  {
    __iterator __tmp = *this;
    ++*this;
    return __tmp;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __iterator& operator--()
    requires __ref_is_glvalue
          && bidirectional_range<_Base> && __bidirectional_common<_InnerBase> && __bidirectional_common<_PatternBase>
  {
    if (__outer_it_ == ranges::end(__parent_->__base_)) {
      auto&& __inner = *--__outer_it_;
      __inner_it_.template emplace<1>(ranges::end(__inner));
    }

    while (true) {
      if (__inner_it_.index() == 0) {
        auto& __it = std::get<0>(__inner_it_);
        if (__it == ranges::begin(__parent_->__pattern_)) {
          auto&& __inner = *--__outer_it_;
          __inner_it_.template emplace<1>(ranges::end(__inner));
        } else
          break;
      } else {
        auto& __it     = std::get<1>(__inner_it_);
        auto&& __inner = *__outer_it_;
        if (__it == ranges::begin(__inner))
          __inner_it_.template emplace<0>(ranges::end(__parent_->__pattern_));
        else
          break;
      }
    }

    std::visit([](auto& __it) { --__it; }, __inner_it_);
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __iterator operator--(int)
    requires __ref_is_glvalue
          && bidirectional_range<_Base> && __bidirectional_common<_InnerBase> && __bidirectional_common<_PatternBase>
  {
    __iterator __tmp = *this;
    --*this;
    return __tmp;
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI friend constexpr bool operator==(const __iterator& __x, const __iterator& __y)
    requires __ref_is_glvalue && forward_range<_Base> && equality_comparable<_InnerIter>
  {
    return __x.__outer_it_ == __y.__outer_it_ && __x.__inner_it_ == __y.__inner_it_;
  }

  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI friend constexpr decltype(auto) iter_move(const __iterator& __x) {
    using __rvalue_reference =
        common_reference_t<iter_rvalue_reference_t<_InnerIter>, iter_rvalue_reference_t<_PatternIter>>;
    return std::visit<__rvalue_reference>(ranges::iter_move, __x.__inner_it_);
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr void iter_swap(const __iterator& __x, const __iterator& __y)
    requires indirectly_swappable<_InnerIter, _PatternIter>
  {
    std::visit(ranges::iter_swap, __x.__inner_it_, __y.__inner_it_);
  }
};

template <input_range _View, forward_range _Pattern>
  requires view<_View> && input_range<range_reference_t<_View>> && view<_Pattern> &&
           __concatable<range_reference_t<_View>, _Pattern>
template <bool _Const>
struct join_with_view<_View, _Pattern>::__sentinel {
private:
  friend join_with_view;

  using _Parent _LIBCPP_NODEBUG = __maybe_const<_Const, join_with_view>;
  using _Base _LIBCPP_NODEBUG   = __maybe_const<_Const, _View>;

  _LIBCPP_NO_UNIQUE_ADDRESS sentinel_t<_Base> __end_ = sentinel_t<_Base>();

  _LIBCPP_HIDE_FROM_ABI constexpr explicit __sentinel(_Parent& __parent) : __end_(ranges::end(__parent.__base_)) {}

  template <bool _OtherConst>
  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI static constexpr auto& __get_outer_of(const __iterator<_OtherConst>& __x) {
    return __x.__get_outer();
  }

public:
  _LIBCPP_HIDE_FROM_ABI __sentinel() = default;

  _LIBCPP_HIDE_FROM_ABI constexpr __sentinel(__sentinel<!_Const> __s)
    requires _Const && convertible_to<sentinel_t<_View>, sentinel_t<_Base>>
      : __end_(std::move(__s.__end_)) {}

  template <bool _OtherConst>
    requires sentinel_for<sentinel_t<_Base>, iterator_t<__maybe_const<_OtherConst, _View>>>
  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator==(const __iterator<_OtherConst>& __x, const __sentinel& __y) {
    return __get_outer_of(__x) == __y.__end_;
  }
};

namespace views {
namespace __join_with_view {
struct __fn {
  template <class _Range, class _Pattern>
  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Range&& __range, _Pattern&& __pattern) const
      noexcept(noexcept(/**/ join_with_view(std::forward<_Range>(__range), std::forward<_Pattern>(__pattern))))
          -> decltype(/*--*/ join_with_view(std::forward<_Range>(__range), std::forward<_Pattern>(__pattern))) {
    return /*-------------*/ join_with_view(std::forward<_Range>(__range), std::forward<_Pattern>(__pattern));
  }

  template <class _Pattern>
    requires constructible_from<decay_t<_Pattern>, _Pattern>
  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Pattern&& __pattern) const
      noexcept(is_nothrow_constructible_v<decay_t<_Pattern>, _Pattern>) {
    return __pipeable(std::__bind_back(*this, std::forward<_Pattern>(__pattern)));
  }
};
} // namespace __join_with_view

inline namespace __cpo {
inline constexpr auto join_with = __join_with_view::__fn{};
} // namespace __cpo
} // namespace views
} // namespace ranges

#endif // _LIBCPP_STD_VER >= 23

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_JOIN_WITH_VIEW_H
