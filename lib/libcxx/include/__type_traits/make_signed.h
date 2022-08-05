//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_MAKE_SIGNED_H
#define _LIBCPP___TYPE_TRAITS_MAKE_SIGNED_H

#include <__config>
#include <__type_traits/apply_cv.h>
#include <__type_traits/is_enum.h>
#include <__type_traits/is_integral.h>
#include <__type_traits/nat.h>
#include <__type_traits/remove_cv.h>
#include <__type_traits/type_list.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

typedef
    __type_list<signed char,
    __type_list<signed short,
    __type_list<signed int,
    __type_list<signed long,
    __type_list<signed long long,
#ifndef _LIBCPP_HAS_NO_INT128
    __type_list<__int128_t,
#endif
    __nat
#ifndef _LIBCPP_HAS_NO_INT128
    >
#endif
    > > > > > __signed_types;

template <class _Tp, bool = is_integral<_Tp>::value || is_enum<_Tp>::value>
struct __make_signed {};

template <class _Tp>
struct __make_signed<_Tp, true>
{
    typedef typename __find_first<__signed_types, sizeof(_Tp)>::type type;
};

template <> struct __make_signed<bool,               true> {};
template <> struct __make_signed<  signed short,     true> {typedef short     type;};
template <> struct __make_signed<unsigned short,     true> {typedef short     type;};
template <> struct __make_signed<  signed int,       true> {typedef int       type;};
template <> struct __make_signed<unsigned int,       true> {typedef int       type;};
template <> struct __make_signed<  signed long,      true> {typedef long      type;};
template <> struct __make_signed<unsigned long,      true> {typedef long      type;};
template <> struct __make_signed<  signed long long, true> {typedef long long type;};
template <> struct __make_signed<unsigned long long, true> {typedef long long type;};
#ifndef _LIBCPP_HAS_NO_INT128
template <> struct __make_signed<__int128_t,         true> {typedef __int128_t type;};
template <> struct __make_signed<__uint128_t,        true> {typedef __int128_t type;};
#endif

template <class _Tp>
struct _LIBCPP_TEMPLATE_VIS make_signed
{
    typedef typename __apply_cv<_Tp, typename __make_signed<typename remove_cv<_Tp>::type>::type>::type type;
};

#if _LIBCPP_STD_VER > 11
template <class _Tp> using make_signed_t = typename make_signed<_Tp>::type;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_MAKE_SIGNED_H
