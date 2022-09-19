//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_STANDARD_LAYOUT_H
#define _LIBCPP___TYPE_TRAITS_IS_STANDARD_LAYOUT_H

#include <__config>
#include <__type_traits/integral_constant.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS is_standard_layout
#if __has_builtin(__is_standard_layout)
    : public integral_constant<bool, __is_standard_layout(_Tp)>
#else
    : integral_constant<bool, is_scalar<typename remove_all_extents<_Tp>::type>::value>
#endif
    {};

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_standard_layout_v = is_standard_layout<_Tp>::value;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_STANDARD_LAYOUT_H
