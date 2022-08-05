//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_HAS_VIRTUAL_DESTRUCTOR_H
#define _LIBCPP___TYPE_TRAITS_HAS_VIRTUAL_DESTRUCTOR_H

#include <__config>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if __has_builtin(__has_virtual_destructor)

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS has_virtual_destructor
    : public integral_constant<bool, __has_virtual_destructor(_Tp)> {};

#else

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS has_virtual_destructor
    : public false_type {};

#endif

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool has_virtual_destructor_v = has_virtual_destructor<_Tp>::value;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_HAS_VIRTUAL_DESTRUCTOR_H
