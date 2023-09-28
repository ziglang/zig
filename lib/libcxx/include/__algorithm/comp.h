//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___ALGORITHM_COMP_H
#define _LIBCPP___ALGORITHM_COMP_H

#include <__config>
#include <__type_traits/integral_constant.h>
#include <__type_traits/predicate_traits.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

struct __equal_to {
  template <class _T1, class _T2>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 bool operator()(const _T1& __x, const _T2& __y) const {
    return __x == __y;
  }
};

template <class _Lhs, class _Rhs>
struct __is_trivial_equality_predicate<__equal_to, _Lhs, _Rhs> : true_type {};

// The definition is required because __less is part of the ABI, but it's empty
// because all comparisons should be transparent.
template <class _T1 = void, class _T2 = _T1>
struct __less {};

template <>
struct __less<void, void> {
  template <class _Tp, class _Up>
  _LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 bool operator()(const _Tp& __lhs, const _Up& __rhs) const {
    return __lhs < __rhs;
  }
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_COMP_H
