// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_REVERSE_ITERATOR_H
#define _LIBCPP___ITERATOR_REVERSE_ITERATOR_H

#include <__algorithm/unwrap_iter.h>
#include <__compare/compare_three_way_result.h>
#include <__compare/three_way_comparable.h>
#include <__concepts/convertible_to.h>
#include <__config>
#include <__iterator/advance.h>
#include <__iterator/concepts.h>
#include <__iterator/incrementable_traits.h>
#include <__iterator/iter_move.h>
#include <__iterator/iter_swap.h>
#include <__iterator/iterator.h>
#include <__iterator/iterator_traits.h>
#include <__iterator/next.h>
#include <__iterator/prev.h>
#include <__iterator/readable_traits.h>
#include <__iterator/segmented_iterator.h>
#include <__memory/addressof.h>
#include <__ranges/access.h>
#include <__ranges/concepts.h>
#include <__ranges/subrange.h>
#include <__type_traits/conditional.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_assignable.h>
#include <__type_traits/is_convertible.h>
#include <__type_traits/is_nothrow_copy_constructible.h>
#include <__type_traits/is_pointer.h>
#include <__type_traits/is_same.h>
#include <__utility/declval.h>
#include <__utility/move.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Iter>
class _LIBCPP_TEMPLATE_VIS reverse_iterator
#if _LIBCPP_STD_VER <= 14 || !defined(_LIBCPP_ABI_NO_ITERATOR_BASES)
    : public iterator<typename iterator_traits<_Iter>::iterator_category,
                      typename iterator_traits<_Iter>::value_type,
                      typename iterator_traits<_Iter>::difference_type,
                      typename iterator_traits<_Iter>::pointer,
                      typename iterator_traits<_Iter>::reference>
#endif
{
  _LIBCPP_SUPPRESS_DEPRECATED_POP

private:
#ifndef _LIBCPP_ABI_NO_ITERATOR_BASES
  _Iter __t_; // no longer used as of LWG #2360, not removed due to ABI break
#endif

#if _LIBCPP_STD_VER >= 20
  static_assert(__has_bidirectional_iterator_category<_Iter>::value || bidirectional_iterator<_Iter>,
                "reverse_iterator<It> requires It to be a bidirectional iterator.");
#endif // _LIBCPP_STD_VER >= 20

protected:
  _Iter current;

public:
  using iterator_type = _Iter;

  using iterator_category =
      _If<__has_random_access_iterator_category<_Iter>::value,
          random_access_iterator_tag,
          typename iterator_traits<_Iter>::iterator_category>;
  using pointer = typename iterator_traits<_Iter>::pointer;
#if _LIBCPP_STD_VER >= 20
  using iterator_concept = _If<random_access_iterator<_Iter>, random_access_iterator_tag, bidirectional_iterator_tag>;
  using value_type       = iter_value_t<_Iter>;
  using difference_type  = iter_difference_t<_Iter>;
  using reference        = iter_reference_t<_Iter>;
#else
  using value_type      = typename iterator_traits<_Iter>::value_type;
  using difference_type = typename iterator_traits<_Iter>::difference_type;
  using reference       = typename iterator_traits<_Iter>::reference;
#endif

#ifndef _LIBCPP_ABI_NO_ITERATOR_BASES
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator() : __t_(), current() {}

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 explicit reverse_iterator(_Iter __x) : __t_(__x), current(__x) {}

  template <class _Up,
            class = __enable_if_t< !is_same<_Up, _Iter>::value && is_convertible<_Up const&, _Iter>::value > >
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator(const reverse_iterator<_Up>& __u)
      : __t_(__u.base()), current(__u.base()) {}

  template <class _Up,
            class = __enable_if_t< !is_same<_Up, _Iter>::value && is_convertible<_Up const&, _Iter>::value &&
                                   is_assignable<_Iter&, _Up const&>::value > >
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator& operator=(const reverse_iterator<_Up>& __u) {
    __t_ = current = __u.base();
    return *this;
  }
#else
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator() : current() {}

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 explicit reverse_iterator(_Iter __x) : current(__x) {}

  template <class _Up,
            class = __enable_if_t< !is_same<_Up, _Iter>::value && is_convertible<_Up const&, _Iter>::value > >
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator(const reverse_iterator<_Up>& __u)
      : current(__u.base()) {}

  template <class _Up,
            class = __enable_if_t< !is_same<_Up, _Iter>::value && is_convertible<_Up const&, _Iter>::value &&
                                   is_assignable<_Iter&, _Up const&>::value > >
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator& operator=(const reverse_iterator<_Up>& __u) {
    current = __u.base();
    return *this;
  }
#endif
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 _Iter base() const { return current; }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reference operator*() const {
    _Iter __tmp = current;
    return *--__tmp;
  }

#if _LIBCPP_STD_VER >= 20
  _LIBCPP_HIDE_FROM_ABI constexpr pointer operator->() const
    requires is_pointer_v<_Iter> || requires(const _Iter __i) { __i.operator->(); }
  {
    if constexpr (is_pointer_v<_Iter>) {
      return std::prev(current);
    } else {
      return std::prev(current).operator->();
    }
  }
#else
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 pointer operator->() const { return std::addressof(operator*()); }
#endif // _LIBCPP_STD_VER >= 20

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator& operator++() {
    --current;
    return *this;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator operator++(int) {
    reverse_iterator __tmp(*this);
    --current;
    return __tmp;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator& operator--() {
    ++current;
    return *this;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator operator--(int) {
    reverse_iterator __tmp(*this);
    ++current;
    return __tmp;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator operator+(difference_type __n) const {
    return reverse_iterator(current - __n);
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator& operator+=(difference_type __n) {
    current -= __n;
    return *this;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator operator-(difference_type __n) const {
    return reverse_iterator(current + __n);
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator& operator-=(difference_type __n) {
    current += __n;
    return *this;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reference operator[](difference_type __n) const {
    return *(*this + __n);
  }

#if _LIBCPP_STD_VER >= 20
  _LIBCPP_HIDE_FROM_ABI friend constexpr iter_rvalue_reference_t<_Iter> iter_move(const reverse_iterator& __i) noexcept(
      is_nothrow_copy_constructible_v<_Iter>&& noexcept(ranges::iter_move(--std::declval<_Iter&>()))) {
    auto __tmp = __i.base();
    return ranges::iter_move(--__tmp);
  }

  template <indirectly_swappable<_Iter> _Iter2>
  _LIBCPP_HIDE_FROM_ABI friend constexpr void
  iter_swap(const reverse_iterator& __x, const reverse_iterator<_Iter2>& __y) noexcept(
      is_nothrow_copy_constructible_v<_Iter> &&
      is_nothrow_copy_constructible_v<_Iter2>&& noexcept(
          ranges::iter_swap(--std::declval<_Iter&>(), --std::declval<_Iter2&>()))) {
    auto __xtmp = __x.base();
    auto __ytmp = __y.base();
    ranges::iter_swap(--__xtmp, --__ytmp);
  }
#endif // _LIBCPP_STD_VER >= 20
};

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 bool
operator==(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
#if _LIBCPP_STD_VER >= 20
  requires requires {
    { __x.base() == __y.base() } -> convertible_to<bool>;
  }
#endif // _LIBCPP_STD_VER >= 20
{
  return __x.base() == __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 bool
operator<(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
#if _LIBCPP_STD_VER >= 20
  requires requires {
    { __x.base() > __y.base() } -> convertible_to<bool>;
  }
#endif // _LIBCPP_STD_VER >= 20
{
  return __x.base() > __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 bool
operator!=(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
#if _LIBCPP_STD_VER >= 20
  requires requires {
    { __x.base() != __y.base() } -> convertible_to<bool>;
  }
#endif // _LIBCPP_STD_VER >= 20
{
  return __x.base() != __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 bool
operator>(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
#if _LIBCPP_STD_VER >= 20
  requires requires {
    { __x.base() < __y.base() } -> convertible_to<bool>;
  }
#endif // _LIBCPP_STD_VER >= 20
{
  return __x.base() < __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 bool
operator>=(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
#if _LIBCPP_STD_VER >= 20
  requires requires {
    { __x.base() <= __y.base() } -> convertible_to<bool>;
  }
#endif // _LIBCPP_STD_VER >= 20
{
  return __x.base() <= __y.base();
}

template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 bool
operator<=(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
#if _LIBCPP_STD_VER >= 20
  requires requires {
    { __x.base() >= __y.base() } -> convertible_to<bool>;
  }
#endif // _LIBCPP_STD_VER >= 20
{
  return __x.base() >= __y.base();
}

#if _LIBCPP_STD_VER >= 20
template <class _Iter1, three_way_comparable_with<_Iter1> _Iter2>
_LIBCPP_HIDE_FROM_ABI constexpr compare_three_way_result_t<_Iter1, _Iter2>
operator<=>(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y) {
  return __y.base() <=> __x.base();
}
#endif // _LIBCPP_STD_VER >= 20

#ifndef _LIBCPP_CXX03_LANG
template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 auto
operator-(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y)
    -> decltype(__y.base() - __x.base()) {
  return __y.base() - __x.base();
}
#else
template <class _Iter1, class _Iter2>
inline _LIBCPP_HIDE_FROM_ABI typename reverse_iterator<_Iter1>::difference_type
operator-(const reverse_iterator<_Iter1>& __x, const reverse_iterator<_Iter2>& __y) {
  return __y.base() - __x.base();
}
#endif

template <class _Iter>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator<_Iter>
operator+(typename reverse_iterator<_Iter>::difference_type __n, const reverse_iterator<_Iter>& __x) {
  return reverse_iterator<_Iter>(__x.base() - __n);
}

#if _LIBCPP_STD_VER >= 20
template <class _Iter1, class _Iter2>
  requires(!sized_sentinel_for<_Iter1, _Iter2>)
inline constexpr bool disable_sized_sentinel_for<reverse_iterator<_Iter1>, reverse_iterator<_Iter2>> = true;
#endif // _LIBCPP_STD_VER >= 20

#if _LIBCPP_STD_VER >= 14
template <class _Iter>
inline _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX17 reverse_iterator<_Iter> make_reverse_iterator(_Iter __i) {
  return reverse_iterator<_Iter>(__i);
}
#endif

#if _LIBCPP_STD_VER <= 17
template <class _Iter>
using __unconstrained_reverse_iterator = reverse_iterator<_Iter>;
#else

// __unconstrained_reverse_iterator allows us to use reverse iterators in the implementation of algorithms by working
// around a language issue in C++20.
// In C++20, when a reverse iterator wraps certain C++20-hostile iterators, calling comparison operators on it will
// result in a compilation error. However, calling comparison operators on the pristine hostile iterator is not
// an error. Thus, we cannot use reverse_iterators in the implementation of an algorithm that accepts a
// C++20-hostile iterator. This class is an internal workaround -- it is a copy of reverse_iterator with
// tweaks to make it support hostile iterators.
//
// A C++20-hostile iterator is one that defines a comparison operator where one of the arguments is an exact match
// and the other requires an implicit conversion, for example:
//   friend bool operator==(const BaseIter&, const DerivedIter&);
//
// C++20 rules for rewriting equality operators create another overload of this function with parameters reversed:
//   friend bool operator==(const DerivedIter&, const BaseIter&);
//
// This creates an ambiguity in overload resolution.
//
// Clang treats this ambiguity differently in different contexts. When operator== is actually called in the function
// body, the code is accepted with a warning. When a concept requires operator== to be a valid expression, however,
// it evaluates to false. Thus, the implementation of reverse_iterator::operator== can actually call operator== on its
// base iterators, but the constraints on reverse_iterator::operator== prevent it from being considered during overload
// resolution. This class simply removes the problematic constraints from comparison functions.
template <class _Iter>
class __unconstrained_reverse_iterator {
  _Iter __iter_;

public:
  static_assert(__has_bidirectional_iterator_category<_Iter>::value || bidirectional_iterator<_Iter>);

  using iterator_type = _Iter;
  using iterator_category =
      _If<__has_random_access_iterator_category<_Iter>::value,
          random_access_iterator_tag,
          __iterator_category_type<_Iter>>;
  using pointer         = __iterator_pointer_type<_Iter>;
  using value_type      = iter_value_t<_Iter>;
  using difference_type = iter_difference_t<_Iter>;
  using reference       = iter_reference_t<_Iter>;

  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator()                                        = default;
  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator(const __unconstrained_reverse_iterator&) = default;
  _LIBCPP_HIDE_FROM_ABI constexpr explicit __unconstrained_reverse_iterator(_Iter __iter) : __iter_(__iter) {}

  _LIBCPP_HIDE_FROM_ABI constexpr _Iter base() const { return __iter_; }
  _LIBCPP_HIDE_FROM_ABI constexpr reference operator*() const {
    auto __tmp = __iter_;
    return *--__tmp;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr pointer operator->() const {
    if constexpr (is_pointer_v<_Iter>) {
      return std::prev(__iter_);
    } else {
      return std::prev(__iter_).operator->();
    }
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr iter_rvalue_reference_t<_Iter>
  iter_move(const __unconstrained_reverse_iterator& __i) noexcept(
      is_nothrow_copy_constructible_v<_Iter>&& noexcept(ranges::iter_move(--std::declval<_Iter&>()))) {
    auto __tmp = __i.base();
    return ranges::iter_move(--__tmp);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator& operator++() {
    --__iter_;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator operator++(int) {
    auto __tmp = *this;
    --__iter_;
    return __tmp;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator& operator--() {
    ++__iter_;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator operator--(int) {
    auto __tmp = *this;
    ++__iter_;
    return __tmp;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator& operator+=(difference_type __n) {
    __iter_ -= __n;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator& operator-=(difference_type __n) {
    __iter_ += __n;
    return *this;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator operator+(difference_type __n) const {
    return __unconstrained_reverse_iterator(__iter_ - __n);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr __unconstrained_reverse_iterator operator-(difference_type __n) const {
    return __unconstrained_reverse_iterator(__iter_ + __n);
  }

  _LIBCPP_HIDE_FROM_ABI constexpr difference_type operator-(const __unconstrained_reverse_iterator& __other) const {
    return __other.__iter_ - __iter_;
  }

  _LIBCPP_HIDE_FROM_ABI constexpr auto operator[](difference_type __n) const { return *(*this + __n); }

  // Deliberately unconstrained unlike the comparison functions in `reverse_iterator` -- see the class comment for the
  // rationale.
  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator==(const __unconstrained_reverse_iterator& __lhs, const __unconstrained_reverse_iterator& __rhs) {
    return __lhs.base() == __rhs.base();
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator!=(const __unconstrained_reverse_iterator& __lhs, const __unconstrained_reverse_iterator& __rhs) {
    return __lhs.base() != __rhs.base();
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator<(const __unconstrained_reverse_iterator& __lhs, const __unconstrained_reverse_iterator& __rhs) {
    return __lhs.base() > __rhs.base();
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator>(const __unconstrained_reverse_iterator& __lhs, const __unconstrained_reverse_iterator& __rhs) {
    return __lhs.base() < __rhs.base();
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator<=(const __unconstrained_reverse_iterator& __lhs, const __unconstrained_reverse_iterator& __rhs) {
    return __lhs.base() >= __rhs.base();
  }

  _LIBCPP_HIDE_FROM_ABI friend constexpr bool
  operator>=(const __unconstrained_reverse_iterator& __lhs, const __unconstrained_reverse_iterator& __rhs) {
    return __lhs.base() <= __rhs.base();
  }
};

#endif // _LIBCPP_STD_VER <= 17

template <template <class> class _RevIter1, template <class> class _RevIter2, class _Iter>
struct __unwrap_reverse_iter_impl {
  using _UnwrappedIter  = decltype(__unwrap_iter_impl<_Iter>::__unwrap(std::declval<_Iter>()));
  using _ReverseWrapper = _RevIter1<_RevIter2<_Iter> >;

  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR _ReverseWrapper
  __rewrap(_ReverseWrapper __orig_iter, _UnwrappedIter __unwrapped_iter) {
    return _ReverseWrapper(
        _RevIter2<_Iter>(__unwrap_iter_impl<_Iter>::__rewrap(__orig_iter.base().base(), __unwrapped_iter)));
  }

  static _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR _UnwrappedIter __unwrap(_ReverseWrapper __i) _NOEXCEPT {
    return __unwrap_iter_impl<_Iter>::__unwrap(__i.base().base());
  }
};

#if _LIBCPP_STD_VER >= 20
template <ranges::bidirectional_range _Range>
_LIBCPP_HIDE_FROM_ABI constexpr ranges::subrange<reverse_iterator<ranges::iterator_t<_Range>>,
                                                 reverse_iterator<ranges::iterator_t<_Range>>>
__reverse_range(_Range&& __range) {
  auto __first = ranges::begin(__range);
  return {std::make_reverse_iterator(ranges::next(__first, ranges::end(__range))), std::make_reverse_iterator(__first)};
}
#endif

template <class _Iter, bool __b>
struct __unwrap_iter_impl<reverse_iterator<reverse_iterator<_Iter> >, __b>
    : __unwrap_reverse_iter_impl<reverse_iterator, reverse_iterator, _Iter> {};

#if _LIBCPP_STD_VER >= 20

template <class _Iter, bool __b>
struct __unwrap_iter_impl<reverse_iterator<__unconstrained_reverse_iterator<_Iter>>, __b>
    : __unwrap_reverse_iter_impl<reverse_iterator, __unconstrained_reverse_iterator, _Iter> {};

template <class _Iter, bool __b>
struct __unwrap_iter_impl<__unconstrained_reverse_iterator<reverse_iterator<_Iter>>, __b>
    : __unwrap_reverse_iter_impl<__unconstrained_reverse_iterator, reverse_iterator, _Iter> {};

template <class _Iter, bool __b>
struct __unwrap_iter_impl<__unconstrained_reverse_iterator<__unconstrained_reverse_iterator<_Iter>>, __b>
    : __unwrap_reverse_iter_impl<__unconstrained_reverse_iterator, __unconstrained_reverse_iterator, _Iter> {};

#endif // _LIBCPP_STD_VER >= 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ITERATOR_REVERSE_ITERATOR_H
