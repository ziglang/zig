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

template <class _T1, class _T2 = _T1>
struct __less
{
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
    bool operator()(const _T1& __x, const _T1& __y) const {return __x < __y;}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
    bool operator()(const _T1& __x, const _T2& __y) const {return __x < __y;}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
    bool operator()(const _T2& __x, const _T1& __y) const {return __x < __y;}

    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
    bool operator()(const _T2& __x, const _T2& __y) const {return __x < __y;}
};

template <class _T1>
struct __less<_T1, _T1>
{
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
    bool operator()(const _T1& __x, const _T1& __y) const {return __x < __y;}
};

template <class _T1>
struct __less<const _T1, _T1>
{
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
    bool operator()(const _T1& __x, const _T1& __y) const {return __x < __y;}
};

template <class _T1>
struct __less<_T1, const _T1>
{
    _LIBCPP_INLINE_VISIBILITY _LIBCPP_CONSTEXPR_SINCE_CXX14
    bool operator()(const _T1& __x, const _T1& __y) const {return __x < __y;}
};

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___ALGORITHM_COMP_H
