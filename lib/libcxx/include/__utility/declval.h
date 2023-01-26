//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___UTILITY_DECLVAL_H
#define _LIBCPP___UTILITY_DECLVAL_H

#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

_LIBCPP_BEGIN_NAMESPACE_STD

// Suppress deprecation notice for volatile-qualified return type resulting
// from volatile-qualified types _Tp.
_LIBCPP_SUPPRESS_DEPRECATED_PUSH
template <class _Tp>
_Tp&& __declval(int);
template <class _Tp>
_Tp __declval(long);
_LIBCPP_SUPPRESS_DEPRECATED_POP

template <class _Tp>
decltype(std::__declval<_Tp>(0)) declval() _NOEXCEPT;

_LIBCPP_END_NAMESPACE_STD

#endif // _LIBCPP___UTILITY_DECLVAL_H
