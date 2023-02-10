//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_TRIVIALLY_ASSIGNABLE_H
#define _LIBCPP___TYPE_TRAITS_IS_TRIVIALLY_ASSIGNABLE_H

#include <__config>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp, class _Arg>
struct is_trivially_assignable
    : integral_constant<bool, __is_trivially_assignable(_Tp, _Arg)>
{ };

#if _LIBCPP_STD_VER > 14
template <class _Tp, class _Arg>
inline constexpr bool is_trivially_assignable_v = is_trivially_assignable<_Tp, _Arg>::value;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_TRIVIALLY_ASSIGNABLE_H
