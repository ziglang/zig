//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_MEMBER_POINTER_H
#define _LIBCPP___TYPE_TRAITS_IS_MEMBER_POINTER_H

#include <__config>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if __has_builtin(__is_member_pointer)

template<class _Tp>
struct _LIBCPP_TEMPLATE_VIS is_member_pointer : _BoolConstant<__is_member_pointer(_Tp)> { };

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_member_pointer_v = __is_member_pointer(_Tp);
#endif

#else // __has_builtin(__is_member_pointer)

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS is_member_pointer
 : public _BoolConstant< __libcpp_is_member_pointer<typename remove_cv<_Tp>::type>::__is_member > {};

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_member_pointer_v = is_member_pointer<_Tp>::value;
#endif

#endif // __has_builtin(__is_member_pointer)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_MEMBER_POINTER_H
