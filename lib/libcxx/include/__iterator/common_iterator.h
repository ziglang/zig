// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_COMMON_ITERATOR_H
#define _LIBCPP___ITERATOR_COMMON_ITERATOR_H

#include <__config>
#include <__debug>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iter_move.h>
#include <__iterator/iter_swap.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/readable_traits.h>
#include <concepts>
#include <variant>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_HAS_NO_RANGES)

template<input_or_output_iterator _Iter, sentinel_for<_Iter> _Sent>
  requires (!same_as<_Iter, _Sent> && copyable<_Iter>)
class common_iterator {
  class __proxy {
    friend common_iterator;

    iter_value_t<_Iter> __value;
    // We can move __x because the only caller verifies that __x is not a reference.
    constexpr __proxy(iter_reference_t<_Iter>&& __x)
      : __value(_VSTD::move(__x)) {}

  public:
    const iter_value_t<_Iter>* operator->() const {
      return _VSTD::addressof(__value);
    }
  };

  class __postfix_proxy {
    friend common_iterator;

    iter_value_t<_Iter> __value;
    constexpr __postfix_proxy(iter_reference_t<_Iter>&& __x)
      : __value(_VSTD::forward<iter_reference_t<_Iter>>(__x)) {}

  public:
    constexpr static bool __valid_for_iter =
      constructible_from<iter_value_t<_Iter>, iter_reference_t<_Iter>> &&
      move_constructible<iter_value_t<_Iter>>;

    const iter_value_t<_Iter>& operator*() const {
      return __value;
    }
  };

public:
  variant<_Iter, _Sent> __hold_;

  common_iterator() requires default_initializable<_Iter> = default;

  constexpr common_iterator(_Iter __i) : __hold_(in_place_type<_Iter>, _VSTD::move(__i)) {}
  constexpr common_iterator(_Sent __s) : __hold_(in_place_type<_Sent>, _VSTD::move(__s)) {}

  template<class _I2, class _S2>
    requires convertible_to<const _I2&, _Iter> && convertible_to<const _S2&, _Sent>
  constexpr common_iterator(const common_iterator<_I2, _S2>& __other)
    : __hold_([&]() -> variant<_Iter, _Sent> {
      _LIBCPP_ASSERT(!__other.__hold_.valueless_by_exception(), "Constructed from valueless iterator.");
      if (__other.__hold_.index() == 0)
        return variant<_Iter, _Sent>{in_place_index<0>, _VSTD::__unchecked_get<0>(__other.__hold_)};
      return variant<_Iter, _Sent>{in_place_index<1>, _VSTD::__unchecked_get<1>(__other.__hold_)};
    }()) {}

  template<class _I2, class _S2>
    requires convertible_to<const _I2&, _Iter> && convertible_to<const _S2&, _Sent> &&
             assignable_from<_Iter&, const _I2&> && assignable_from<_Sent&, const _S2&>
  common_iterator& operator=(const common_iterator<_I2, _S2>& __other) {
    _LIBCPP_ASSERT(!__other.__hold_.valueless_by_exception(), "Assigned from valueless iterator.");

    auto __idx = __hold_.index();
    auto __other_idx = __other.__hold_.index();

    // If they're the same index, just assign.
    if (__idx == 0 && __other_idx == 0)
      _VSTD::__unchecked_get<0>(__hold_) = _VSTD::__unchecked_get<0>(__other.__hold_);
    else if (__idx == 1 && __other_idx == 1)
      _VSTD::__unchecked_get<1>(__hold_) = _VSTD::__unchecked_get<1>(__other.__hold_);

    // Otherwise replace with the oposite element.
    else if (__other_idx == 1)
      __hold_.template emplace<1>(_VSTD::__unchecked_get<1>(__other.__hold_));
    else if (__other_idx == 0)
      __hold_.template emplace<0>(_VSTD::__unchecked_get<0>(__other.__hold_));

    return *this;
  }

  decltype(auto) operator*()
  {
    _LIBCPP_ASSERT(holds_alternative<_Iter>(__hold_),
                   "Cannot dereference sentinel. Common iterator not holding an iterator.");
    return *_VSTD::__unchecked_get<_Iter>(__hold_);
  }

  decltype(auto) operator*() const
    requires __dereferenceable<const _Iter>
  {
    _LIBCPP_ASSERT(holds_alternative<_Iter>(__hold_),
                   "Cannot dereference sentinel. Common iterator not holding an iterator.");
    return *_VSTD::__unchecked_get<_Iter>(__hold_);
  }

  template<class _I2 = _Iter>
  decltype(auto) operator->() const
    requires indirectly_readable<const _I2> &&
    (requires(const _I2& __i) { __i.operator->(); } ||
     is_reference_v<iter_reference_t<_I2>> ||
     constructible_from<iter_value_t<_I2>, iter_reference_t<_I2>>)
  {
    _LIBCPP_ASSERT(holds_alternative<_Iter>(__hold_),
                   "Cannot dereference sentinel. Common iterator not holding an iterator.");

    if constexpr (is_pointer_v<_Iter> || requires(const _Iter& __i) { __i.operator->(); })    {
      return _VSTD::__unchecked_get<_Iter>(__hold_);
    } else if constexpr (is_reference_v<iter_reference_t<_Iter>>) {
      auto&& __tmp = *_VSTD::__unchecked_get<_Iter>(__hold_);
      return _VSTD::addressof(__tmp);
    } else {
      return __proxy(*_VSTD::__unchecked_get<_Iter>(__hold_));
    }
  }

  common_iterator& operator++() {
    _LIBCPP_ASSERT(holds_alternative<_Iter>(__hold_),
                   "Cannot increment sentinel. Common iterator not holding an iterator.");
    ++_VSTD::__unchecked_get<_Iter>(__hold_); return *this;
  }

  decltype(auto) operator++(int) {
    _LIBCPP_ASSERT(holds_alternative<_Iter>(__hold_),
                   "Cannot increment sentinel. Common iterator not holding an iterator.");

    if constexpr (forward_iterator<_Iter>) {
      auto __tmp = *this;
      ++*this;
      return __tmp;
    } else if constexpr (requires (_Iter& __i) { { *__i++ } -> __referenceable; } ||
                         !__postfix_proxy::__valid_for_iter) {
      return _VSTD::__unchecked_get<_Iter>(__hold_)++;
    } else {
      __postfix_proxy __p(**this);
      ++*this;
      return __p;
    }
  }

  template<class _I2, sentinel_for<_Iter> _S2>
    requires sentinel_for<_Sent, _I2>
  friend bool operator==(const common_iterator& __x, const common_iterator<_I2, _S2>& __y) {
    _LIBCPP_ASSERT(!__x.__hold_.valueless_by_exception() &&
                   !__y.__hold_.valueless_by_exception(),
                   "One or both common_iterators are valueless. (Cannot compare valueless iterators.)");

    auto __x_index = __x.__hold_.index();
    auto __y_index = __y.__hold_.index();

    if (__x_index == __y_index)
      return true;

    if (__x_index == 0)
      return _VSTD::__unchecked_get<_Iter>(__x.__hold_) == _VSTD::__unchecked_get<_S2>(__y.__hold_);

    return _VSTD::__unchecked_get<_Sent>(__x.__hold_) == _VSTD::__unchecked_get<_I2>(__y.__hold_);
  }

  template<class _I2, sentinel_for<_Iter> _S2>
    requires sentinel_for<_Sent, _I2> && equality_comparable_with<_Iter, _I2>
  friend bool operator==(const common_iterator& __x, const common_iterator<_I2, _S2>& __y) {
    _LIBCPP_ASSERT(!__x.__hold_.valueless_by_exception() &&
                   !__y.__hold_.valueless_by_exception(),
                   "One or both common_iterators are valueless. (Cannot compare valueless iterators.)");

    auto __x_index = __x.__hold_.index();
    auto __y_index = __y.__hold_.index();

    if (__x_index == 1 && __y_index == 1)
      return true;

    if (__x_index == 0 && __y_index == 0)
      return  _VSTD::__unchecked_get<_Iter>(__x.__hold_) ==  _VSTD::__unchecked_get<_I2>(__y.__hold_);

    if (__x_index == 0)
      return  _VSTD::__unchecked_get<_Iter>(__x.__hold_) == _VSTD::__unchecked_get<_S2>(__y.__hold_);

    return _VSTD::__unchecked_get<_Sent>(__x.__hold_) ==  _VSTD::__unchecked_get<_I2>(__y.__hold_);
  }

  template<sized_sentinel_for<_Iter> _I2, sized_sentinel_for<_Iter> _S2>
    requires sized_sentinel_for<_Sent, _I2>
  friend iter_difference_t<_I2> operator-(const common_iterator& __x, const common_iterator<_I2, _S2>& __y) {
    _LIBCPP_ASSERT(!__x.__hold_.valueless_by_exception() &&
                   !__y.__hold_.valueless_by_exception(),
                   "One or both common_iterators are valueless. (Cannot subtract valueless iterators.)");

    auto __x_index = __x.__hold_.index();
    auto __y_index = __y.__hold_.index();

    if (__x_index == 1 && __y_index == 1)
      return 0;

    if (__x_index == 0 && __y_index == 0)
      return  _VSTD::__unchecked_get<_Iter>(__x.__hold_) - _VSTD::__unchecked_get<_I2>(__y.__hold_);

    if (__x_index == 0)
      return  _VSTD::__unchecked_get<_Iter>(__x.__hold_) - _VSTD::__unchecked_get<_S2>(__y.__hold_);

    return _VSTD::__unchecked_get<_Sent>(__x.__hold_) - _VSTD::__unchecked_get<_I2>(__y.__hold_);
  }

  friend iter_rvalue_reference_t<_Iter> iter_move(const common_iterator& __i)
    noexcept(noexcept(ranges::iter_move(declval<const _Iter&>())))
      requires input_iterator<_Iter>
  {
    _LIBCPP_ASSERT(holds_alternative<_Iter>(__i.__hold_),
                   "Cannot iter_move a sentinel. Common iterator not holding an iterator.");
    return ranges::iter_move( _VSTD::__unchecked_get<_Iter>(__i.__hold_));
  }

  template<indirectly_swappable<_Iter> _I2, class _S2>
  friend void iter_swap(const common_iterator& __x, const common_iterator<_I2, _S2>& __y)
      noexcept(noexcept(ranges::iter_swap(declval<const _Iter&>(), declval<const _I2&>())))
  {
    _LIBCPP_ASSERT(holds_alternative<_Iter>(__x.__hold_),
                   "Cannot swap __y with a sentinel. Common iterator (__x) not holding an iterator.");
    _LIBCPP_ASSERT(holds_alternative<_Iter>(__y.__hold_),
                   "Cannot swap __x with a sentinel. Common iterator (__y) not holding an iterator.");
    return ranges::iter_swap( _VSTD::__unchecked_get<_Iter>(__x.__hold_),  _VSTD::__unchecked_get<_Iter>(__y.__hold_));
  }
};

template<class _Iter, class _Sent>
struct incrementable_traits<common_iterator<_Iter, _Sent>> {
  using difference_type = iter_difference_t<_Iter>;
};

template<class _Iter>
concept __denotes_forward_iter =
  requires { typename iterator_traits<_Iter>::iterator_category; } &&
  derived_from<typename iterator_traits<_Iter>::iterator_category, forward_iterator_tag>;

template<class _Iter, class _Sent>
concept __common_iter_has_ptr_op = requires(const common_iterator<_Iter, _Sent>& __a) {
  __a.operator->();
};

template<class, class>
struct __arrow_type_or_void {
    using type = void;
};

template<class _Iter, class _Sent>
  requires __common_iter_has_ptr_op<_Iter, _Sent>
struct __arrow_type_or_void<_Iter, _Sent> {
    using type = decltype(declval<const common_iterator<_Iter, _Sent>>().operator->());
};

template<class _Iter, class _Sent>
struct iterator_traits<common_iterator<_Iter, _Sent>> {
  using iterator_concept = _If<forward_iterator<_Iter>,
                               forward_iterator_tag,
                               input_iterator_tag>;
  using iterator_category = _If<__denotes_forward_iter<_Iter>,
                                forward_iterator_tag,
                                input_iterator_tag>;
  using pointer = typename __arrow_type_or_void<_Iter, _Sent>::type;
  using value_type = iter_value_t<_Iter>;
  using difference_type = iter_difference_t<_Iter>;
  using reference = iter_reference_t<_Iter>;
};


#endif // !defined(_LIBCPP_HAS_NO_RANGES)

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___ITERATOR_COMMON_ITERATOR_H
