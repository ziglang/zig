//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_NOTHROW_MOVE_CONSTRUCTIBLE_H
#define _LIBCPP___TYPE_TRAITS_IS_NOTHROW_MOVE_CONSTRUCTIBLE_H

#include <__config>
#include <__type_traits/add_rvalue_reference.h>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_nothrow_constructible.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS is_nothrow_move_constructible
    : public is_nothrow_constructible<_Tp, typename add_rvalue_reference<_Tp>::type>
    {};

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_nothrow_move_constructible_v = is_nothrow_move_constructible<_Tp>::value;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_NOTHROW_MOVE_CONSTRUCTIBLE_H
