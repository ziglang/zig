//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ITERATOR_PRODUCT_ITERATOR_H
#define _LIBCPP___ITERATOR_PRODUCT_ITERATOR_H

// Product iterators are iterators that contain two or more underlying iterators.
//
// For example, std::flat_map stores its data into two separate containers, and its iterator
// is a proxy over two separate underlying iterators. The concept of product iterators
// allows algorithms to operate over these underlying iterators separately, opening the
// door to various optimizations.
//
// If __product_iterator_traits can be instantiated, the following functions and associated types must be provided:
// - static constexpr size_t Traits::__size
//   The number of underlying iterators inside the product iterator.
//
// - template <size_t _N>
//   static decltype(auto) Traits::__get_iterator_element(It&& __it)
//   Returns the _Nth iterator element of the given product iterator.
//
// - template <class... _Iters>
//   static _Iterator __make_product_iterator(_Iters&&...);
//   Creates a product iterator from the given underlying iterators.

#include <__config>
#include <__cstddef/size_t.h>
#include <__type_traits/enable_if.h>
#include <__type_traits/integral_constant.h>
#include <__utility/declval.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Iterator>
struct __product_iterator_traits;
/* exposition-only:
{
  static constexpr size_t __size = ...;

  template <size_t _N, class _Iter>
  static decltype(auto) __get_iterator_element(_Iter&&);

  template <class... _Iters>
  static _Iterator __make_product_iterator(_Iters&&...);
};
*/

template <class _Tp, size_t = 0>
struct __is_product_iterator : false_type {};

template <class _Tp>
struct __is_product_iterator<_Tp, sizeof(__product_iterator_traits<_Tp>) * 0> : true_type {};

template <class _Tp, size_t _Size, class = void>
struct __is_product_iterator_of_size : false_type {};

template <class _Tp, size_t _Size>
struct __is_product_iterator_of_size<_Tp, _Size, __enable_if_t<__product_iterator_traits<_Tp>::__size == _Size> >
    : true_type {};

template <class _Iterator, size_t _Nth>
using __product_iterator_element_t _LIBCPP_NODEBUG =
    decltype(__product_iterator_traits<_Iterator>::template __get_iterator_element<_Nth>(std::declval<_Iterator>()));

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ITERATOR_PRODUCT_ITERATOR_H
