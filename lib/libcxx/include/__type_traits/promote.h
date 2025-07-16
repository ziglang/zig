//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___TYPE_TRAITS_PROMOTE_H
#define _LIBCPP___TYPE_TRAITS_PROMOTE_H

#include <__config>
#include <__type_traits/enable_if.h>
#include <__type_traits/is_arithmetic.h>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

float __promote_impl(float);
double __promote_impl(char);
double __promote_impl(int);
double __promote_impl(unsigned);
double __promote_impl(long);
double __promote_impl(unsigned long);
double __promote_impl(long long);
double __promote_impl(unsigned long long);
#if _LIBCPP_HAS_INT128
double __promote_impl(__int128_t);
double __promote_impl(__uint128_t);
#endif
double __promote_impl(double);
long double __promote_impl(long double);

template <class... _Args>
using __promote_t _LIBCPP_NODEBUG =
    decltype((__enable_if_t<(is_arithmetic<_Args>::value && ...)>)0, (std::__promote_impl(_Args()) + ...));

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___TYPE_TRAITS_PROMOTE_H
