// -*- C++ -*-
//===-----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
// This adds support for the extended locale functions that are currently
// missing from the Musl C library.
//
// This only works when the specified locale is "C" or "POSIX", but that's
// about as good as we can do without implementing full xlocale support
// in Musl.
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___SUPPORT_MUSL_XLOCALE_H
#define _LIBCPP___SUPPORT_MUSL_XLOCALE_H

#include <cstdlib>
#include <cwchar>

#ifdef __cplusplus
extern "C" {
#endif

inline _LIBCPP_HIDE_FROM_ABI_C long long strtoll_l(const char* __nptr, char** __endptr, int __base, locale_t) {
  return ::strtoll(__nptr, __endptr, __base);
}

inline _LIBCPP_HIDE_FROM_ABI_C unsigned long long
strtoull_l(const char* __nptr, char** __endptr, int __base, locale_t) {
  return ::strtoull(__nptr, __endptr, __base);
}

inline _LIBCPP_HIDE_FROM_ABI_C long long wcstoll_l(const wchar_t* __nptr, wchar_t** __endptr, int __base, locale_t) {
  return ::wcstoll(__nptr, __endptr, __base);
}

inline _LIBCPP_HIDE_FROM_ABI_C long long wcstoull_l(const wchar_t* __nptr, wchar_t** __endptr, int __base, locale_t) {
  return ::wcstoull(__nptr, __endptr, __base);
}

inline _LIBCPP_HIDE_FROM_ABI_C long double wcstold_l(const wchar_t* __nptr, wchar_t** __endptr, locale_t) {
  return ::wcstold(__nptr, __endptr);
}

#ifdef __cplusplus
}
#endif

#endif // _LIBCPP___SUPPORT_MUSL_XLOCALE_H
