//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_INTEGER_TRAITS_H
#define _LIBCPP___TYPE_TRAITS_INTEGER_TRAITS_H

#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// This trait is to determine whether a type is a /signed integer type/
// See [basic.fundamental]/p1
template <class _Tp>
inline const bool __is_signed_integer_v = false;
template <>
inline const bool __is_signed_integer_v<signed char> = true;
template <>
inline const bool __is_signed_integer_v<signed short> = true;
template <>
inline const bool __is_signed_integer_v<signed int> = true;
template <>
inline const bool __is_signed_integer_v<signed long> = true;
template <>
inline const bool __is_signed_integer_v<signed long long> = true;
#if _LIBCPP_HAS_INT128
template <>
inline const bool __is_signed_integer_v<__int128_t> = true;
#endif

// This trait is to determine whether a type is an /unsigned integer type/
// See [basic.fundamental]/p2
template <class _Tp>
inline const bool __is_unsigned_integer_v = false;
template <>
inline const bool __is_unsigned_integer_v<unsigned char> = true;
template <>
inline const bool __is_unsigned_integer_v<unsigned short> = true;
template <>
inline const bool __is_unsigned_integer_v<unsigned int> = true;
template <>
inline const bool __is_unsigned_integer_v<unsigned long> = true;
template <>
inline const bool __is_unsigned_integer_v<unsigned long long> = true;
#if _LIBCPP_HAS_INT128
template <>
inline const bool __is_unsigned_integer_v<__uint128_t> = true;
#endif

#if _LIBCPP_STD_VER >= 20
template <class _Tp>
concept __signed_integer = __is_signed_integer_v<_Tp>;

template <class _Tp>
concept __unsigned_integer = __is_unsigned_integer_v<_Tp>;

// This isn't called __integer, because an integer type according to [basic.fundamental]/p11 is the same as an integral
// type. An integral type is _not_ the same set of types as signed and unsigned integer types combined.
template <class _Tp>
concept __signed_or_unsigned_integer = __signed_integer<_Tp> || __unsigned_integer<_Tp>;
#endif

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_INTEGER_TRAITS_H
