// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_BOUNDED_ITER_H
#define _LIBCPP___ITERATOR_BOUNDED_ITER_H

#include <__assert>
#include <__config>
#include <__iterator/iterator_traits.h>
#include <__memory/pointer_traits.h>
#include <__utility/move.h>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// Iterator wrapper that carries the valid range it is allowed to access.
//
// This is a simple iterator wrapper for contiguous iterators that points
// within a [begin, end) range and carries these bounds with it. The iterator
// ensures that it is pointing within that [begin, end) range when it is
// dereferenced.
//
// Arithmetic operations are allowed and the bounds of the resulting iterator
// are not checked. Hence, it is possible to create an iterator pointing outside
// its range, but it is not possible to dereference it.
template <class _Iterator, class = __enable_if_t< __is_cpp17_contiguous_iterator<_Iterator>::value > >
struct __bounded_iter {
  using value_type        = typename iterator_traits<_Iterator>::value_type;
  using difference_type   = typename iterator_traits<_Iterator>::difference_type;
  using pointer           = typename iterator_traits<_Iterator>::pointer;
  using reference         = typename iterator_traits<_Iterator>::reference;
  using iterator_category = typename iterator_traits<_Iterator>::iterator_category;
#if _LIBCPP_STD_VER > 17
  using iterator_concept = contiguous_iterator_tag;
#endif

  // Create a singular iterator.
  //
  // Such an iterator does not point to any object and is conceptually out of bounds, so it is
  // not dereferenceable. Observing operations like comparison and assignment are valid.
  _LIBCPP_HIDE_FROM_ABI __bounded_iter() = default;

  _LIBCPP_HIDE_FROM_ABI __bounded_iter(__bounded_iter const&) = default;
  _LIBCPP_HIDE_FROM_ABI __bounded_iter(__bounded_iter&&)      = default;

  template <class _OtherIterator, class = __enable_if_t< is_convertible<_OtherIterator, _Iterator>::value > >
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR __bounded_iter(__bounded_iter<_OtherIterator> const& __other) _NOEXCEPT
      : __current_(__other.__current_),
        __begin_(__other.__begin_),
        __end_(__other.__end_) {}

  // Assign a bounded iterator to another one, rebinding the bounds of the iterator as well.
  _LIBCPP_HIDE_FROM_ABI __bounded_iter& operator=(__bounded_iter const&) = default;
  _LIBCPP_HIDE_FROM_ABI __bounded_iter& operator=(__bounded_iter&&)      = default;

private:
  // Create an iterator wrapping the given iterator, and whose bounds are described
  // by the provided [begin, end) range.
  //
  // This constructor does not check whether the resulting iterator is within its bounds.
  // However, it does check that the provided [begin, end) range is a valid range (that
  // is, begin <= end).
  //
  // Since it is non-standard for iterators to have this constructor, __bounded_iter must
  // be created via `std::__make_bounded_iter`.
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 explicit __bounded_iter(
      _Iterator __current, _Iterator __begin, _Iterator __end)
      : __current_(__current), __begin_(__begin), __end_(__end) {
    _LIBCPP_ASSERT(__begin <= __end, "__bounded_iter(current, begin, end): [begin, end) is not a valid range");
  }

  template <class _It>
  friend _LIBCPP_CONSTEXPR __bounded_iter<_It> __make_bounded_iter(_It, _It, _It);

public:
  // Dereference and indexing operations.
  //
  // These operations check that the iterator is dereferenceable, that is within [begin, end).
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 reference operator*() const _NOEXCEPT {
    _LIBCPP_ASSERT(
        __in_bounds(__current_), "__bounded_iter::operator*: Attempt to dereference an out-of-range iterator");
    return *__current_;
  }

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 pointer operator->() const _NOEXCEPT {
    _LIBCPP_ASSERT(
        __in_bounds(__current_), "__bounded_iter::operator->: Attempt to dereference an out-of-range iterator");
    return std::__to_address(__current_);
  }

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 reference operator[](difference_type __n) const _NOEXCEPT {
    _LIBCPP_ASSERT(
        __in_bounds(__current_ + __n), "__bounded_iter::operator[]: Attempt to index an iterator out-of-range");
    return __current_[__n];
  }

  // Arithmetic operations.
  //
  // These operations do not check that the resulting iterator is within the bounds, since that
  // would make it impossible to create a past-the-end iterator.
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 __bounded_iter& operator++() _NOEXCEPT {
    ++__current_;
    return *this;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 __bounded_iter operator++(int) _NOEXCEPT {
    __bounded_iter __tmp(*this);
    ++*this;
    return __tmp;
  }

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 __bounded_iter& operator--() _NOEXCEPT {
    --__current_;
    return *this;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 __bounded_iter operator--(int) _NOEXCEPT {
    __bounded_iter __tmp(*this);
    --*this;
    return __tmp;
  }

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 __bounded_iter& operator+=(difference_type __n) _NOEXCEPT {
    __current_ += __n;
    return *this;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 friend __bounded_iter
  operator+(__bounded_iter const& __self, difference_type __n) _NOEXCEPT {
    __bounded_iter __tmp(__self);
    __tmp += __n;
    return __tmp;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 friend __bounded_iter
  operator+(difference_type __n, __bounded_iter const& __self) _NOEXCEPT {
    __bounded_iter __tmp(__self);
    __tmp += __n;
    return __tmp;
  }

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 __bounded_iter& operator-=(difference_type __n) _NOEXCEPT {
    __current_ -= __n;
    return *this;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 friend __bounded_iter
  operator-(__bounded_iter const& __self, difference_type __n) _NOEXCEPT {
    __bounded_iter __tmp(__self);
    __tmp -= __n;
    return __tmp;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_AFTER_CXX11 friend difference_type
  operator-(__bounded_iter const& __x, __bounded_iter const& __y) _NOEXCEPT {
    return __x.__current_ - __y.__current_;
  }

  // Comparison operations.
  //
  // These operations do not check whether the iterators are within their bounds.
  // The valid range for each iterator is also not considered as part of the comparison,
  // i.e. two iterators pointing to the same location will be considered equal even
  // if they have different validity ranges.
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR friend bool
  operator==(__bounded_iter const& __x, __bounded_iter const& __y) _NOEXCEPT {
    return __x.__current_ == __y.__current_;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR friend bool
  operator!=(__bounded_iter const& __x, __bounded_iter const& __y) _NOEXCEPT {
    return __x.__current_ != __y.__current_;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR friend bool
  operator<(__bounded_iter const& __x, __bounded_iter const& __y) _NOEXCEPT {
    return __x.__current_ < __y.__current_;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR friend bool
  operator>(__bounded_iter const& __x, __bounded_iter const& __y) _NOEXCEPT {
    return __x.__current_ > __y.__current_;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR friend bool
  operator<=(__bounded_iter const& __x, __bounded_iter const& __y) _NOEXCEPT {
    return __x.__current_ <= __y.__current_;
  }
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR friend bool
  operator>=(__bounded_iter const& __x, __bounded_iter const& __y) _NOEXCEPT {
    return __x.__current_ >= __y.__current_;
  }

private:
  // Return whether the given iterator is in the bounds of this __bounded_iter.
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR bool __in_bounds(_Iterator const& __iter) const {
    return __iter >= __begin_ && __iter < __end_;
  }

  template <class>
  friend struct pointer_traits;
  _Iterator __current_;       // current iterator
  _Iterator __begin_, __end_; // valid range represented as [begin, end)
};

template <class _It>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR __bounded_iter<_It> __make_bounded_iter(_It __it, _It __begin, _It __end) {
  return __bounded_iter<_It>(std::move(__it), std::move(__begin), std::move(__end));
}

#if _LIBCPP_STD_VER <= 17
template <class _Iterator>
struct __is_cpp17_contiguous_iterator<__bounded_iter<_Iterator> > : true_type {};
#endif

template <class _Iterator>
struct pointer_traits<__bounded_iter<_Iterator> > {
  using pointer         = __bounded_iter<_Iterator>;
  using element_type    = typename pointer_traits<_Iterator>::element_type;
  using difference_type = typename pointer_traits<_Iterator>::difference_type;

  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR static element_type* to_address(pointer __it) _NOEXCEPT {
    return std::__to_address(__it.__current_);
  }
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ITERATOR_BOUNDED_ITER_H
