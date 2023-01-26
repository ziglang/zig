// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___RANGES_ELEMENTS_VIEW_H
#define _LIBCPP___RANGES_ELEMENTS_VIEW_H

#include <__compare/three_way_comparable.h>
#include <__concepts/constructible.h>
#include <__concepts/convertible_to.h>
#include <__concepts/derived_from.h>
#include <__concepts/equality_comparable.h>
#include <__config>
#include <__fwd/get.h>
#include <__iterator/concepts.h>
#include <__iterator/iterator_traits.h>
#include <__ranges/access.h>
#include <__ranges/all.h>
#include <__ranges/concepts.h>
#include <__ranges/enable_borrowed_range.h>
#include <__ranges/range_adaptor.h>
#include <__ranges/size.h>
#include <__ranges/view_interface.h>
#include <__tuple_dir/tuple_element.h>
#include <__tuple_dir/tuple_like.h>
#include <__tuple_dir/tuple_size.h>
#include <__type_traits/is_reference.h>
#include <__type_traits/maybe_const.h>
#include <__type_traits/remove_cv.h>
#include <__type_traits/remove_cvref.h>
#include <__type_traits/remove_reference.h>
#include <__utility/declval.h>
#include <__utility/forward.h>
#include <__utility/move.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 20

namespace ranges {

template <class _View, size_t _Np, bool _Const>
class __elements_view_iterator;

template <class _View, size_t _Np, bool _Const>
class __elements_view_sentinel;

template <class _Tp, size_t _Np>
concept __has_tuple_element = __tuple_like<_Tp> && _Np < tuple_size<_Tp>::value;

template <class _Tp, size_t _Np>
concept __returnable_element = is_reference_v<_Tp> || move_constructible<tuple_element_t<_Np, _Tp>>;

template <input_range _View, size_t _Np>
  requires view<_View> && __has_tuple_element<range_value_t<_View>, _Np> &&
           __has_tuple_element<remove_reference_t<range_reference_t<_View>>, _Np> &&
           __returnable_element<range_reference_t<_View>, _Np>
class elements_view : public view_interface<elements_view<_View, _Np>> {
public:
  _LIBCPP_HIDE_FROM_ABI elements_view()
    requires default_initializable<_View>
  = default;

  _LIBCPP_HIDE_FROM_ABI constexpr explicit elements_view(_View __base) : __base_(std::move(__base)) {}

  _LIBCPP_HIDE_FROM_ABI constexpr _View base() const&
    requires copy_constructible<_View>
  {
    return __base_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr _View base() && { return std::move(__base_); }

  _LIBCPP_HIDE_FROM_ABI constexpr auto begin()
    requires(!__simple_view<_View>)
  {
    return __iterator</*_Const=*/false>(ranges::begin(__base_));
  }

  _LIBCPP_HIDE_FROM_ABI constexpr auto begin() const
    requires range<const _View>
  {
    return __iterator</*_Const=*/true>(ranges::begin(__base_));
  }

  _LIBCPP_HIDE_FROM_ABI constexpr auto end()
    requires(!__simple_view<_View> && !common_range<_View>)
  {
    return __sentinel</*_Const=*/false>{ranges::end(__base_)};
  }

  _LIBCPP_HIDE_FROM_ABI constexpr auto end()
    requires(!__simple_view<_View> && common_range<_View>)
  {
    return __iterator</*_Const=*/false>{ranges::end(__base_)};
  }

  _LIBCPP_HIDE_FROM_ABI constexpr auto end() const
    requires range<const _View>
  {
    return __sentinel</*_Const=*/true>{ranges::end(__base_)};
  }

  _LIBCPP_HIDE_FROM_ABI constexpr auto end() const
    requires common_range<const _View>
  {
    return __iterator</*_Const=*/true>{ranges::end(__base_)};
  }

  _LIBCPP_HIDE_FROM_ABI constexpr auto size()
    requires sized_range<_View>
  {
    return ranges::size(__base_);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr auto size() const
    requires sized_range<const _View>
  {
    return ranges::size(__base_);
  }

private:
  template <bool _Const>
  using __iterator = __elements_view_iterator<_View, _Np, _Const>;

  template <bool _Const>
  using __sentinel = __elements_view_sentinel<_View, _Np, _Const>;

  _LIBCPP_NO_UNIQUE_ADDRESS _View __base_ = _View();
};

template <class, size_t>
struct __elements_view_iterator_category_base {};

template <forward_range _Base, size_t _Np>
struct __elements_view_iterator_category_base<_Base, _Np> {
  static consteval auto __get_iterator_category() {
    using _Result = decltype(std::get<_Np>(*std::declval<iterator_t<_Base>>()));
    using _Cat    = typename iterator_traits<iterator_t<_Base>>::iterator_category;

    if constexpr (!is_lvalue_reference_v<_Result>) {
      return input_iterator_tag{};
    } else if constexpr (derived_from<_Cat, random_access_iterator_tag>) {
      return random_access_iterator_tag{};
    } else {
      return _Cat{};
    }
  }

  using iterator_category = decltype(__get_iterator_category());
};

template <class _View, size_t _Np, bool _Const>
class __elements_view_iterator : public __elements_view_iterator_category_base<__maybe_const<_Const, _View>, _Np> {
  template <class, size_t, bool >
  friend class __elements_view_iterator;

  template <class, size_t, bool >
  friend class __elements_view_sentinel;

  using _Base = __maybe_const<_Const, _View>;

  iterator_t<_Base> __current_ = iterator_t<_Base>();

  _LIBCPP_HIDE_FROM_ABI static constexpr decltype(auto) __get_element(const iterator_t<_Base>& __i) {
    if constexpr (is_reference_v<range_reference_t<_Base>>) {
      return std::get<_Np>(*__i);
    } else {
      using _Element = remove_cv_t<tuple_element_t<_Np, range_reference_t<_Base>>>;
      return static_cast<_Element>(std::get<_Np>(*__i));
    }
  }

  static consteval auto __get_iterator_concept() {
    if constexpr (random_access_range<_Base>) {
      return random_access_iterator_tag{};
    } else if constexpr (bidirectional_range<_Base>) {
      return bidirectional_iterator_tag{};
    } else if constexpr (forward_range<_Base>) {
      return forward_iterator_tag{};
    } else {
      return input_iterator_tag{};
    }
  }

public:
  using iterator_concept = decltype(__get_iterator_concept());
  using value_type       = remove_cvref_t<tuple_element_t<_Np, range_value_t<_Base>>>;
  using difference_type  = range_difference_t<_Base>;

  _LIBCPP_HIDE_FROM_ABI __elements_view_iterator()
    requires default_initializable<iterator_t<_Base>>
  = default;

  _LIBCPP_HIDE_FROM_ABI constexpr explicit __elements_view_iterator(iterator_t<_Base> __current)
      : __current_(std::move(__current)) {}

  _LIBCPP_HIDE_FROM_ABI constexpr __elements_view_iterator(__elements_view_iterator<_View, _Np, !_Const> __i)
    requires _Const && convertible_to<iterator_t<_View>, iterator_t<_Base>>
      : __current_(std::move(__i.__current_)) {}

  _LIBCPP_HIDE_FROM_ABI constexpr const iterator_t<_Base>& base() const& noexcept { return __current_; }

  _LIBCPP_HIDE_FROM_ABI constexpr iterator_t<_Base> base() && { return std::move(__current_); }

  _LIBCPP_HIDE_FROM_ABI constexpr decltype(auto) operator*() const { return __get_element(__current_); }

  _LIBCPP_HIDE_FROM_ABI constexpr __elements_view_iterator& operator++() {
    ++__current_;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr void operator++(int) { ++__current_; }

  _LIBCPP_HIDE_FROM_ABI constexpr __elements_view_iterator operator++(int)
    requires forward_range<_Base>
  {
    auto temp = *this;
    ++__current_;
    return temp;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __elements_view_iterator& operator--()
    requires bidirectional_range<_Base>
  {
    --__current_;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __elements_view_iterator operator--(int)
    requires bidirectional_range<_Base>
  {
    auto temp = *this;
    --__current_;
    return temp;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __elements_view_iterator& operator+=(difference_type __n)
    requires random_access_range<_Base>
  {
    __current_ += __n;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __elements_view_iterator& operator-=(difference_type __n)
    requires random_access_range<_Base>
  {
    __current_ -= __n;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr decltype(auto) operator[](difference_type __n) const
    requires random_access_range<_Base>
  {
    return __get_element(__current_ + __n);
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator==(const __elements_view_iterator& __x, const __elements_view_iterator& __y)
    requires equality_comparable<iterator_t<_Base>>
  {
    return __x.__current_ == __y.__current_;
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator<(const __elements_view_iterator& __x, const __elements_view_iterator& __y)
    requires random_access_range<_Base>
  {
    return __x.__current_ < __y.__current_;
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator>(const __elements_view_iterator& __x, const __elements_view_iterator& __y)
    requires random_access_range<_Base>
  {
    return __y < __x;
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator<=(const __elements_view_iterator& __x, const __elements_view_iterator& __y)
    requires random_access_range<_Base>
  {
    return !(__y < __x);
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator>=(const __elements_view_iterator& __x, const __elements_view_iterator& __y)
    requires random_access_range<_Base>
  {
    return !(__x < __y);
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr auto
  operator<=>(const __elements_view_iterator& __x, const __elements_view_iterator& __y)
    requires random_access_range<_Base> && three_way_comparable<iterator_t<_Base>>
  {
    return __x.__current_ <=> __y.__current_;
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr __elements_view_iterator
  operator+(const __elements_view_iterator& __x, difference_type __y)
    requires random_access_range<_Base>
  {
    return __elements_view_iterator{__x} += __y;
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr __elements_view_iterator
  operator+(difference_type __x, const __elements_view_iterator& __y)
    requires random_access_range<_Base>
  {
    return __y + __x;
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr __elements_view_iterator
  operator-(const __elements_view_iterator& __x, difference_type __y)
    requires random_access_range<_Base>
  {
    return __elements_view_iterator{__x} -= __y;
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr difference_type
  operator-(const __elements_view_iterator& __x, const __elements_view_iterator& __y)
    requires sized_sentinel_for<iterator_t<_Base>, iterator_t<_Base>>
  {
    return __x.__current_ - __y.__current_;
  }
};

template <class _View, size_t _Np, bool _Const>
class __elements_view_sentinel {
private:
  using _Base                                        = __maybe_const<_Const, _View>;
  _LIBCPP_NO_UNIQUE_ADDRESS sentinel_t<_Base> __end_ = sentinel_t<_Base>();

  template <class, size_t, bool >
  friend class __elements_view_sentinel;

  template <bool _AnyConst>
  _LIBCPP_HIDE_FROM_ABI static constexpr decltype(auto)
  __get_current(const __elements_view_iterator<_View, _Np, _AnyConst>& __iter) {
    return (__iter.__current_);
  }

public:
  _LIBCPP_HIDE_FROM_ABI __elements_view_sentinel() = default;

  _LIBCPP_HIDE_FROM_ABI constexpr explicit __elements_view_sentinel(sentinel_t<_Base> __end)
      : __end_(std::move(__end)) {}

  _LIBCPP_HIDE_FROM_ABI constexpr __elements_view_sentinel(__elements_view_sentinel<_View, _Np, !_Const> __other)
    requires _Const && convertible_to<sentinel_t<_View>, sentinel_t<_Base>>
      : __end_(std::move(__other.__end_)) {}

  _LIBCPP_HIDE_FROM_ABI constexpr sentinel_t<_Base> base() const { return __end_; }

  template <bool _OtherConst>
    requires sentinel_for<sentinel_t<_Base>, iterator_t<__maybe_const<_OtherConst, _View>>>
  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator==(const __elements_view_iterator<_View, _Np, _OtherConst>& __x, const __elements_view_sentinel& __y) {
    return __get_current(__x) == __y.__end_;
  }

  template <bool _OtherConst>
    requires sized_sentinel_for<sentinel_t<_Base>, iterator_t<__maybe_const<_OtherConst, _View>>>
  _LIBCPP_HIDE_FROM_ABI friend constexpr range_difference_t<__maybe_const<_OtherConst, _View>>
  operator-(const __elements_view_iterator<_View, _Np, _OtherConst>& __x, const __elements_view_sentinel& __y) {
    return __get_current(__x) - __y.__end_;
  }

  template <bool _OtherConst>
    requires sized_sentinel_for<sentinel_t<_Base>, iterator_t<__maybe_const<_OtherConst, _View>>>
  _LIBCPP_HIDE_FROM_ABI friend constexpr range_difference_t<__maybe_const<_OtherConst, _View>>
  operator-(const __elements_view_sentinel& __x, const __elements_view_iterator<_View, _Np, _OtherConst>& __y) {
    return __x.__end_ - __get_current(__y);
  }
};

template <class _Tp, size_t _Np>
inline constexpr bool enable_borrowed_range<elements_view<_Tp, _Np>> = enable_borrowed_range<_Tp>;

template <class _Tp>
using keys_view = elements_view<_Tp, 0>;
template <class _Tp>
using values_view = elements_view<_Tp, 1>;

namespace views {
namespace __elements {

template <size_t _Np>
struct __fn : __range_adaptor_closure<__fn<_Np>> {
  template <class _Range>
  [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr auto operator()(_Range&& __range) const
      /**/ noexcept(noexcept(elements_view<all_t<_Range&&>, _Np>(std::forward<_Range>(__range))))
      /*------*/ -> decltype(elements_view<all_t<_Range&&>, _Np>(std::forward<_Range>(__range))) {
    /*-------------*/ return elements_view<all_t<_Range&&>, _Np>(std::forward<_Range>(__range));
  }
};
} // namespace __elements

inline namespace __cpo {
template <size_t _Np>
inline constexpr auto elements = __elements::__fn<_Np>{};
inline constexpr auto keys     = elements<0>;
inline constexpr auto values   = elements<1>;
} // namespace __cpo
} // namespace views
} // namespace ranges

#endif // _LIBCPP_STD_VER >= 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___RANGES_ELEMENTS_VIEW_H
