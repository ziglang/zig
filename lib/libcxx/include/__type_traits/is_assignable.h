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

template<typename, typename _Tp> struct __select_2nd { typedef _LIBCPP_NODEBUG _Tp type; };

#if __has_builtin(__is_assignable)

template<class _Tp, class _Up>
struct _LIBCPP_TEMPLATE_VIS is_assignable : _BoolConstant<__is_assignable(_Tp, _Up)> { };

#if _LIBCPP_STD_VER > 14
template <class _Tp, class _Arg>
inline constexpr bool is_assignable_v = __is_assignable(_Tp, _Arg);
#endif

#else // __has_builtin(__is_assignable)

template <class _Tp, class _Arg>
typename __select_2nd<decltype((declval<_Tp>() = declval<_Arg>())), true_type>::type
__is_assignable_test(int);

template <class, class>
false_type __is_assignable_test(...);


template <class _Tp, class _Arg, bool = is_void<_Tp>::value || is_void<_Arg>::value>
struct __is_assignable_imp
    : public decltype((_VSTD::__is_assignable_test<_Tp, _Arg>(0))) {};

template <class _Tp, class _Arg>
struct __is_assignable_imp<_Tp, _Arg, true>
    : public false_type
{
};

template <class _Tp, class _Arg>
struct is_assignable
    : public __is_assignable_imp<_Tp, _Arg> {};

#if _LIBCPP_STD_VER > 14
template <class _Tp, class _Arg>
inline constexpr bool is_assignable_v = is_assignable<_Tp, _Arg>::value;
#endif

#endif // __has_builtin(__is_assignable)

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_ASSIGNABLE_H
