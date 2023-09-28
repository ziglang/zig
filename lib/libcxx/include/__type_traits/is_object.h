//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_OBJECT_H
#define _LIBCPP___TYPE_TRAITS_IS_OBJECT_H

#include <__config>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_array.h>
#include <__type_traits/is_class.h>
#include <__type_traits/is_scalar.h>
#include <__type_traits/is_union.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if __has_builtin(__is_object)

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS is_object : _BoolConstant<__is_object(_Tp)> {};

#  if _LIBCPP_STD_VER >= 17
template <class _Tp>
inline constexpr bool is_object_v = __is_object(_Tp);
#  endif

#else // __has_builtin(__is_object)

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS is_object
    : public integral_constant<bool,
                               is_scalar<_Tp>::value || is_array<_Tp>::value || is_union<_Tp>::value ||
                                   is_class<_Tp>::value > {};

#  if _LIBCPP_STD_VER >= 17
template <class _Tp>
inline constexpr bool is_object_v = is_object<_Tp>::value;
#  endif

#endif // __has_builtin(__is_object)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_OBJECT_H
