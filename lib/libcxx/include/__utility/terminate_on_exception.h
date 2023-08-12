//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_TERMINATE_ON_EXCEPTION_H
#define _LIBCPP___UTILITY_TERMINATE_ON_EXCEPTION_H

#include <__config>
#include <__exception/terminate.h>
#include <new>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#if _LIBCPP_STD_VER >= 17

_LIBCPP_BEGIN_NAMESPACE_STD

#  ifndef _LIBCPP_HAS_NO_EXCEPTIONS

template <class _Func>
_LIBCPP_HIDE_FROM_ABI auto __terminate_on_exception(_Func __func) {
  try {
    return __func();
  } catch (...) {
    std::terminate();
  }
}

#  else // _LIBCPP_HAS_NO_EXCEPTIONS

template <class _Func>
_LIBCPP_HIDE_FROM_ABI auto __terminate_on_exception(_Func __func) {
  return __func();
}

#  endif // _LIBCPP_HAS_NO_EXCEPTIONS

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP_STD_VER >= 17

#endif // _LIBCPP___UTILITY_TERMINATE_ON_EXCEPTION_H
