//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_ASSIGNABLE_H
#define _LIBCPP___TYPE_TRAITS_IS_ASSIGNABLE_H

#include <__config>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp, class _Up>
struct _LIBCPP_TEMPLATE_VIS is_assignable : _BoolConstant<__is_assignable(_Tp, _Up)> {};

#if _LIBCPP_STD_VER >= 17
template <class _Tp, class _Arg>
inline constexpr bool is_assignable_v = __is_assignable(_Tp, _Arg);
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_ASSIGNABLE_H
