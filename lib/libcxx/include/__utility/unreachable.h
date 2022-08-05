//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_UNREACHABLE_H
#define _LIBCPP___UTILITY_UNREACHABLE_H

#include <__config>
#include <cstdlib>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

_LIBCPP_NORETURN _LIBCPP_HIDE_FROM_ABI inline void __libcpp_unreachable()
{
#if __has_builtin(__builtin_unreachable)
  __builtin_unreachable();
#else
  std::abort();
#endif
}

#if _LIBCPP_STD_VER > 20

[[noreturn]] _LIBCPP_HIDE_FROM_ABI inline void unreachable() { __libcpp_unreachable(); }

#endif // _LIBCPP_STD_VER > 20

_LIBCPP_END_NAMESPACE_STD

#endif
