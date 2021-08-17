// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef _LIBCPP___RANGES_SUBRANGE_H
#define _LIBCPP___RANGES_SUBRANGE_H

#include <__config>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/advance.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/dangling.h>
#include <__ranges/enable_borrowed_range.h>
#include <__ranges/size.h>
#include <__ranges/view_interface.h>
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
  template<class _From, class _To>
  concept __convertible_to_non_slicing =
    convertible_to<_From, _To> &&
    // If they're both pointers, they must have the same element type.
    !(is_pointer_v<decay_t<_From>> &&
      is_pointer_v<decay_t<_To>> &&
      __different_from<remove_pointer_t<decay_t<_From>>, remove_pointer_t<decay_t<_To>>>);

  template<class _Tp>
  concept __pair_like =
    !is_reference_v<_Tp> && requires(_Tp __t) {
      typename tuple_size<_Tp>::type; // Ensures `tuple_size<T>` is complete.
      requires derived_from<tuple_size<_Tp>, integral_constant<size_t, 2>>;
      typename tuple_element_t<0, remove_const_t<_Tp>>;
      typename tuple_element_t<1, remove_const_t<_Tp>>;
      { _VSTD::get<0>(__t) } -> convertible_to<const tuple_element_t<0, _Tp>&>;
      { _VSTD::get<1>(__t) } -> convertible_to<const tuple_element_t<1, _Tp>&>;
    };

  template<class _Pair, class _Iter, class _Sent>
  concept __pair_like_convertible_from =
    !range<_Pair> && __pair_like<_Pair> &&
    constructible_from<_Pair, _Iter, _Sent> &&
    __convertible_to_non_slicing<_Iter, tuple_element_t<0, _Pair>> &&
    convertible_to<_Sent, tuple_element_t<1, _Pair>>;

  enum class _LIBCPP_ENUM_VIS subrange_kind : bool { unsized, sized };

  template<class _Iter, class _Sent, bool>
  struct __subrange_base {
    static constexpr bool __store_size = false;
    _Iter __begin_ = _Iter();
    _Sent __end_ = _Sent();

    _LIBCPP_HIDE_FROM_ABI
    constexpr __subrange_base() = default;

    _LIBCPP_HIDE_FROM_ABI
    constexpr __subrange_base(_Iter __iter, _Sent __sent, make_unsigned_t<iter_difference_t<_Iter>> = 0)
      : __begin_(_VSTD::move(__iter)), __end_(__sent) { }
  };

  template<class _Iter, class _Sent>
  struct __subrange_base<_Iter, _Sent, true> {
    static constexpr bool __store_size = true;
    _Iter __begin_ = _Iter();
    _Sent __end_ = _Sent();
    make_unsigned_t<iter_difference_t<_Iter>> __size_ = 0;

    _LIBCPP_HIDE_FROM_ABI
    constexpr __subrange_base() = default;

    _LIBCPP_HIDE_FROM_ABI
    constexpr __subrange_base(_Iter __iter, _Sent __sent, decltype(__size_) __size)
      : __begin_(_VSTD::move(__iter)), __end_(__sent), __size_(__size) { }
  };

  template<input_or_output_iterator _Iter, sentinel_for<_Iter> _Sent = _Iter,
           subrange_kind _Kind = sized_sentinel_for<_Sent, _Iter>
             ? subrange_kind::sized
             : subrange_kind::unsized>
    requires (_Kind == subrange_kind::sized || !sized_sentinel_for<_Sent, _Iter>)
  struct _LIBCPP_TEMPLATE_VIS subrange
    : public view_interface<subrange<_Iter, _Sent, _Kind>>,
      private __subrange_base<_Iter, _Sent, _Kind == subrange_kind::sized && !sized_sentinel_for<_Sent, _Iter>> {

    using _Base = __subrange_base<_Iter, _Sent, _Kind == subrange_kind::sized && !sized_sentinel_for<_Sent, _Iter>>;

    _LIBCPP_HIDE_FROM_ABI
    subrange() requires default_initializable<_Iter> = default;

    _LIBCPP_HIDE_FROM_ABI
    constexpr subrange(__convertible_to_non_slicing<_Iter> auto __iter, _Sent __sent)
      requires (!_Base::__store_size)
      : _Base(_VSTD::move(__iter), __sent) {}

    _LIBCPP_HIDE_FROM_ABI
    constexpr subrange(__convertible_to_non_slicing<_Iter> auto __iter, _Sent __sent,
                       make_unsigned_t<iter_difference_t<_Iter>> __n)
      requires (_Kind == subrange_kind::sized)
      : _Base(_VSTD::move(__iter), __sent, __n) { }

    template<__different_from<subrange> _Range>
      requires borrowed_range<_Range> &&
               __convertible_to_non_slicing<iterator_t<_Range>, _Iter> &&
               convertible_to<sentinel_t<_Range>, _Sent>
    _LIBCPP_HIDE_FROM_ABI
    constexpr subrange(_Range&& __range)
      requires (!_Base::__store_size)
      : subrange(ranges::begin(__range), ranges::end(__range)) { }

    template<__different_from<subrange> _Range>
      requires borrowed_range<_Range> &&
               __convertible_to_non_slicing<iterator_t<_Range>, _Iter> &&
               convertible_to<sentinel_t<_Range>, _Sent>
    _LIBCPP_HIDE_FROM_ABI
    constexpr subrange(_Range&& __range)
      requires _Base::__store_size && sized_range<_Range>
      : subrange(__range, ranges::size(__range)) { }


    template<borrowed_range _Range>
      requires __convertible_to_non_slicing<iterator_t<_Range>, _Iter> &&
               convertible_to<sentinel_t<_Range>, _Sent>
    _LIBCPP_HIDE_FROM_ABI
    constexpr subrange(_Range&& __range, make_unsigned_t<iter_difference_t<_Iter>> __n)
      requires (_Kind == subrange_kind::sized)
      : subrange(ranges::begin(__range), ranges::end(__range), __n) { }

    template<__different_from<subrange> _Pair>
      requires __pair_like_convertible_from<_Pair, const _Iter&, const _Sent&>
    _LIBCPP_HIDE_FROM_ABI
    constexpr operator _Pair() const { return _Pair(this->__begin_, this->__end_); }

    _LIBCPP_HIDE_FROM_ABI
    constexpr _Iter begin() const requires copyable<_Iter> {
      return this->__begin_;
    }

    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr _Iter begin() requires (!copyable<_Iter>) {
      return _VSTD::move(this->__begin_);
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr _Sent end() const { return this->__end_; }

    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr bool empty() const { return this->__begin_ == this->__end_; }

    _LIBCPP_HIDE_FROM_ABI
    constexpr make_unsigned_t<iter_difference_t<_Iter>> size() const
      requires (_Kind == subrange_kind::sized)
    {
      if constexpr (_Base::__store_size)
        return this->__size_;
      else
        return __to_unsigned_like(this->__end_ - this->__begin_);
    }

    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr subrange next(iter_difference_t<_Iter> __n = 1) const&
      requires forward_iterator<_Iter> {
      auto __tmp = *this;
      __tmp.advance(__n);
      return __tmp;
    }

    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr subrange next(iter_difference_t<_Iter> __n = 1) && {
      advance(__n);
      return _VSTD::move(*this);
    }

    [[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr subrange prev(iter_difference_t<_Iter> __n = 1) const
      requires bidirectional_iterator<_Iter> {
      auto __tmp = *this;
      __tmp.advance(-__n);
      return __tmp;
    }

    _LIBCPP_HIDE_FROM_ABI
    constexpr subrange& advance(iter_difference_t<_Iter> __n) {
      if constexpr (bidirectional_iterator<_Iter>) {
        if (__n < 0) {
          ranges::advance(this->__begin_, __n);
          if constexpr (_Base::__store_size)
            this->__size_ += _VSTD::__to_unsigned_like(-__n);
          return *this;
        }
      }

      auto __d = __n - ranges::advance(this->__begin_, __n, this->__end_);
      if constexpr (_Base::__store_size)
        this->__size_ -= _VSTD::__to_unsigned_like(__d);
      return *this;
    }
  };

  template<input_or_output_iterator _Iter, sentinel_for<_Iter> _Sent>
  subrange(_Iter, _Sent) -> subrange<_Iter, _Sent>;

  template<input_or_output_iterator _Iter, sentinel_for<_Iter> _Sent>
  subrange(_Iter, _Sent, make_unsigned_t<iter_difference_t<_Iter>>)
    -> subrange<_Iter, _Sent, subrange_kind::sized>;

  template<borrowed_range _Range>
  subrange(_Range&&) -> subrange<iterator_t<_Range>, sentinel_t<_Range>,
                                 (sized_range<_Range> || sized_sentinel_for<sentinel_t<_Range>, iterator_t<_Range>>)
                                   ? subrange_kind::sized : subrange_kind::unsized>;

  template<borrowed_range _Range>
  subrange(_Range&&, make_unsigned_t<range_difference_t<_Range>>)
    -> subrange<iterator_t<_Range>, sentinel_t<_Range>, subrange_kind::sized>;

  template<size_t _Index, class _Iter, class _Sent, subrange_kind _Kind>
    requires (_Index < 2)
  _LIBCPP_HIDE_FROM_ABI
  constexpr auto get(const subrange<_Iter, _Sent, _Kind>& __subrange) {
    if constexpr (_Index == 0)
      return __subrange.begin();
    else
      return __subrange.end();
  }

  template<size_t _Index, class _Iter, class _Sent, subrange_kind _Kind>
    requires (_Index < 2)
  _LIBCPP_HIDE_FROM_ABI
  constexpr auto get(subrange<_Iter, _Sent, _Kind>&& __subrange) {
    if constexpr (_Index == 0)
      return __subrange.begin();
    else
      return __subrange.end();
  }

  template<class _Ip, class _Sp, subrange_kind _Kp>
  inline constexpr bool enable_borrowed_range<subrange<_Ip, _Sp, _Kp>> = true;

  template<range _Rp>
  using borrowed_subrange_t = _If<borrowed_range<_Rp>, subrange<iterator_t<_Rp> >, dangling>;
} // namespace ranges

using ranges::get;

// clang-format off

#endif // !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___RANGES_SUBRANGE_H
