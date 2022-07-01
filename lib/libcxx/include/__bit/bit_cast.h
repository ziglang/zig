// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___BIT_BIT_CAST_H
#define _LIBCPP___BIT_BIT_CAST_H

#include <__config>
#include <type_traits>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 17

template<class _ToType, class _FromType, class = enable_if_t<
  sizeof(_ToType) == sizeof(_FromType) &&
  is_trivially_copyable_v<_ToType> &&
  is_trivially_copyable_v<_FromType>
>>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI
constexpr _ToType bit_cast(_FromType const& __from) noexcept {
    return __builtin_bit_cast(_ToType, __from);
}

#endif // _LIBCPP_STD_VER > 17

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___BIT_BIT_CAST_H
