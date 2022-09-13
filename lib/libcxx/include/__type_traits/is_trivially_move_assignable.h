//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_TRIVIALLY_MOVE_ASSIGNABLE_H
#define _LIBCPP___TYPE_TRAITS_IS_TRIVIALLY_MOVE_ASSIGNABLE_H

#include <__config>
#include <__type_traits/add_lvalue_reference.h>
#include <__type_traits/add_rvalue_reference.h>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_trivially_assignable.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS is_trivially_move_assignable
    : public is_trivially_assignable<typename add_lvalue_reference<_Tp>::type,
                                     typename add_rvalue_reference<_Tp>::type>
    {};

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_trivially_move_assignable_v = is_trivially_move_assignable<_Tp>::value;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_TRIVIALLY_MOVE_ASSIGNABLE_H
