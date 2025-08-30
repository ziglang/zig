//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_CONVERTIBLE_H
#define _LIBCPP___TYPE_TRAITS_IS_CONVERTIBLE_H

#include <__config>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _T1, class _T2>
struct _LIBCPP_NO_SPECIALIZATIONS is_convertible : integral_constant<bool, __is_convertible(_T1, _T2)> {};

#if _LIBCPP_STD_VER >= 17
template <class _From, class _To>
_LIBCPP_NO_SPECIALIZATIONS inline constexpr bool is_convertible_v = __is_convertible(_From, _To);
#endif

#if _LIBCPP_STD_VER >= 20

template <class _Tp, class _Up>
struct _LIBCPP_NO_SPECIALIZATIONS is_nothrow_convertible : bool_constant<__is_nothrow_convertible(_Tp, _Up)> {};

template <class _Tp, class _Up>
_LIBCPP_NO_SPECIALIZATIONS inline constexpr bool is_nothrow_convertible_v = __is_nothrow_convertible(_Tp, _Up);

#endif // _LIBCPP_STD_VER >= 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_CONVERTIBLE_H
