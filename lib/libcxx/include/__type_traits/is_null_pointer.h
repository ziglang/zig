//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_NULL_POINTER_H
#define _LIBCPP___TYPE_TRAITS_IS_NULL_POINTER_H

#include <__config>
#include <__type_traits/integral_constant.h>
#include <__type_traits/remove_cv.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp> struct __is_nullptr_t_impl       : public false_type {};
template <>          struct __is_nullptr_t_impl<nullptr_t> : public true_type {};

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS __is_nullptr_t
    : public __is_nullptr_t_impl<__remove_cv_t<_Tp> > {};

#if _LIBCPP_STD_VER > 11
template <class _Tp> struct _LIBCPP_TEMPLATE_VIS is_null_pointer
    : public __is_nullptr_t_impl<__remove_cv_t<_Tp> > {};

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_null_pointer_v = is_null_pointer<_Tp>::value;
#endif
#endif // _LIBCPP_STD_VER > 11

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_NULL_POINTER_H
