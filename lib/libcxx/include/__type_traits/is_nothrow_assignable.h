//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_NOTHROW_ASSIGNABLE_H
#define _LIBCPP___TYPE_TRAITS_IS_NOTHROW_ASSIGNABLE_H

#include <__config>
#include <__type_traits/add_const.h>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if __has_builtin(__is_nothrow_assignable)

template <class _Tp, class _Arg>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_assignable
    : public integral_constant<bool, __is_nothrow_assignable(_Tp, _Arg)> {};

#else

template <bool, class _Tp, class _Arg> struct __libcpp_is_nothrow_assignable;

template <class _Tp, class _Arg>
struct __libcpp_is_nothrow_assignable<false, _Tp, _Arg>
    : public false_type
{
};

template <class _Tp, class _Arg>
struct __libcpp_is_nothrow_assignable<true, _Tp, _Arg>
    : public integral_constant<bool, noexcept(declval<_Tp>() = declval<_Arg>()) >
{
};

template <class _Tp, class _Arg>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_assignable
    : public __libcpp_is_nothrow_assignable<is_assignable<_Tp, _Arg>::value, _Tp, _Arg>
{
};

#endif // __has_builtin(__is_nothrow_assignable)

#if _LIBCPP_STD_VER > 14
template <class _Tp, class _Arg>
inline constexpr bool is_nothrow_assignable_v = is_nothrow_assignable<_Tp, _Arg>::value;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_NOTHROW_ASSIGNABLE_H
