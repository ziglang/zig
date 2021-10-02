// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___VARIANT_MONOSTATE_H
#define _LIBCPP___VARIANT_MONOSTATE_H

#include <__config>
#include <__functional/hash.h>
#include <cstddef>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#pragma GCC system_header
#endif

_LIBCPP_PUSH_MACROS
#include <__undef_macros>

_LIBCPP_BEGIN_NAMESPACE_STD

#if _LIBCPP_STD_VER > 14

struct _LIBCPP_TEMPLATE_VIS monostate {};

inline _LIBCPP_INLINE_VISIBILITY
constexpr bool operator<(monostate, monostate) noexcept { return false; }

inline _LIBCPP_INLINE_VISIBILITY
constexpr bool operator>(monostate, monostate) noexcept { return false; }

inline _LIBCPP_INLINE_VISIBILITY
constexpr bool operator<=(monostate, monostate) noexcept { return true; }

inline _LIBCPP_INLINE_VISIBILITY
constexpr bool operator>=(monostate, monostate) noexcept { return true; }

inline _LIBCPP_INLINE_VISIBILITY
constexpr bool operator==(monostate, monostate) noexcept { return true; }

inline _LIBCPP_INLINE_VISIBILITY
constexpr bool operator!=(monostate, monostate) noexcept { return false; }

template <>
struct _LIBCPP_TEMPLATE_VIS hash<monostate> {
  using argument_type = monostate;
  using result_type = size_t;

  inline _LIBCPP_INLINE_VISIBILITY
  result_type operator()(const argument_type&) const _NOEXCEPT {
    return 66740831; // return a fundamentally attractive random value.
  }
};

#endif // _LIBCPP_STD_VER > 14

_LIBCPP_END_NAMESPACE_STD

_LIBCPP_POP_MACROS

#endif // _LIBCPP___VARIANT_MONOSTATE_H
