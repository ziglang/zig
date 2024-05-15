//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___BIT_ROTATE_H
#define _LIBCPP___BIT_ROTATE_H

#include <__concepts/arithmetic.h>
#include <__config>
#include <__type_traits/is_unsigned_integer.h>
#include <limits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _Tp __rotr(_Tp __t, int __cnt) _NOEXCEPT {
  static_assert(__libcpp_is_unsigned_integer<_Tp>::value, "__rotr requires an unsigned integer type");
  const unsigned int __dig = numeric_limits<_Tp>::digits;
  if ((__cnt % __dig) == 0)
    return __t;

  if (__cnt < 0) {
    __cnt *= -1;
    return (__t << (__cnt % __dig)) | (__t >> (__dig - (__cnt % __dig))); // rotr with negative __cnt is similar to rotl
  }

  return (__t >> (__cnt % __dig)) | (__t << (__dig - (__cnt % __dig)));
}

template <class _Tp>
_LIBCPP_HIDE_FROM_ABI _LIBCPP_CONSTEXPR_SINCE_CXX14 _Tp __rotl(_Tp __t, int __cnt) _NOEXCEPT {
  return std::__rotr(__t, -__cnt);
}

#if _LIBCPP_STD_VER >= 20

template <__libcpp_unsigned_integer _Tp>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr _Tp rotl(_Tp __t, int __cnt) noexcept {
  return std::__rotl(__t, __cnt);
}

template <__libcpp_unsigned_integer _Tp>
[[nodiscard]] _LIBCPP_HIDE_FROM_ABI constexpr _Tp rotr(_Tp __t, int __cnt) noexcept {
  return std::__rotr(__t, __cnt);
}

#endif // _LIBCPP_STD_VER >= 20

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___BIT_ROTATE_H
