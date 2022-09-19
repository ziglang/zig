//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_POD_H
#define _LIBCPP___TYPE_TRAITS_IS_POD_H

#include <__config>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if __has_builtin(__is_pod)

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS is_pod
    : public integral_constant<bool, __is_pod(_Tp)> {};

#else

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS is_pod
    : public integral_constant<bool, is_trivially_default_constructible<_Tp>::value   &&
                                     is_trivially_copy_constructible<_Tp>::value      &&
                                     is_trivially_copy_assignable<_Tp>::value    &&
                                     is_trivially_destructible<_Tp>::value> {};

#endif // __has_builtin(__is_pod)

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_pod_v = is_pod<_Tp>::value;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_POD_H
