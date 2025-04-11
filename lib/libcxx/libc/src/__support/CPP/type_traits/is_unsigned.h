//===-- is_unsigned type_traits ---------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef LLVM_LIBC_SRC___SUPPORT_CPP_TYPE_TRAITS_IS_UNSIGNED_H
#define LLVM_LIBC_SRC___SUPPORT_CPP_TYPE_TRAITS_IS_UNSIGNED_H

#include "src/__support/CPP/type_traits/bool_constant.h"
#include "src/__support/CPP/type_traits/is_arithmetic.h"
#include "src/__support/macros/attributes.h"
#include "src/__support/macros/config.h"

namespace LIBC_NAMESPACE_DECL {
namespace cpp {

// is_unsigned
template <typename T>
struct is_unsigned : bool_constant<(is_arithmetic_v<T> && (T(-1) > T(0)))> {
  LIBC_INLINE constexpr operator bool() const { return is_unsigned::value; }
  LIBC_INLINE constexpr bool operator()() const { return is_unsigned::value; }
};
template <typename T>
LIBC_INLINE_VAR constexpr bool is_unsigned_v = is_unsigned<T>::value;

} // namespace cpp
} // namespace LIBC_NAMESPACE_DECL

#endif // LLVM_LIBC_SRC___SUPPORT_CPP_TYPE_TRAITS_IS_UNSIGNED_H
