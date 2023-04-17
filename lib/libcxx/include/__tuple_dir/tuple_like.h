//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TUPLE_TUPLE_LIKE_H
#define _LIBCPP___TUPLE_TUPLE_LIKE_H

#include <__config>
#include <__fwd/array.h>
#include <__fwd/pair.h>
#include <__fwd/subrange.h>
#include <__fwd/tuple.h>
#include <__type_traits/integral_constant.h>
#include <__type_traits/remove_cvref.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER >= 20

template <class _Tp>
struct __tuple_like_impl : false_type {};

template <class... _Tp>
struct __tuple_like_impl<tuple<_Tp...> > : true_type {};

template <class _T1, class _T2>
struct __tuple_like_impl<pair<_T1, _T2> > : true_type {};

template <class _Tp, size_t _Size>
struct __tuple_like_impl<array<_Tp, _Size> > : true_type {};

template <class _Ip, class _Sp, ranges::subrange_kind _Kp>
struct __tuple_like_impl<ranges::subrange<_Ip, _Sp, _Kp> > : true_type {};

template <class _Tp>
concept __tuple_like = __tuple_like_impl<remove_cvref_t<_Tp>>::value;

#endif // _LIBCPP_STD_VER >= 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TUPLE_TUPLE_LIKE_H
