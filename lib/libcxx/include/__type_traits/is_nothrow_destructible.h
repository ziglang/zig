//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_IS_NOTHROW_DESTRUCTIBLE_H
#define _LIBCPP___TYPE_TRAITS_IS_NOTHROW_DESTRUCTIBLE_H

#include <__config>
#include <__type_traits/add_const.h>
#include <__type_traits/integral_constant.h>
#include <__type_traits/is_destructible.h>
#include <__type_traits/is_reference.h>
#include <__type_traits/is_scalar.h>
#include <__type_traits/remove_all_extents.h>
#include <__utility/declval.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if !defined(_LIBCPP_CXX03_LANG)

template <bool, class _Tp> struct __libcpp_is_nothrow_destructible;

template <class _Tp>
struct __libcpp_is_nothrow_destructible<false, _Tp>
    : public false_type
{
};

template <class _Tp>
struct __libcpp_is_nothrow_destructible<true, _Tp>
    : public integral_constant<bool, noexcept(declval<_Tp>().~_Tp()) >
{
};

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_destructible
    : public __libcpp_is_nothrow_destructible<is_destructible<_Tp>::value, _Tp>
{
};

template <class _Tp, size_t _Ns>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_destructible<_Tp[_Ns]>
    : public is_nothrow_destructible<_Tp>
{
};

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_destructible<_Tp&>
    : public true_type
{
};

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_destructible<_Tp&&>
    : public true_type
{
};

#else

template <class _Tp> struct __libcpp_nothrow_destructor
    : public integral_constant<bool, is_scalar<_Tp>::value ||
                                     is_reference<_Tp>::value> {};

template <class _Tp> struct _LIBCPP_TEMPLATE_VIS is_nothrow_destructible
    : public __libcpp_nothrow_destructor<typename remove_all_extents<_Tp>::type> {};

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS is_nothrow_destructible<_Tp[]>
    : public false_type {};

#endif

#if _LIBCPP_STD_VER > 14
template <class _Tp>
inline constexpr bool is_nothrow_destructible_v = is_nothrow_destructible<_Tp>::value;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_IS_NOTHROW_DESTRUCTIBLE_H
