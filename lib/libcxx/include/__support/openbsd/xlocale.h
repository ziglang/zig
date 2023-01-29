// -*- C++ -*-
//===-----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP___SUPPORT_OPENBSD_XLOCALE_H
#define _LIBCPP___SUPPORT_OPENBSD_XLOCALE_H

#include <__support/xlocale/__strtonum_fallback.h>
#include <clocale>
#include <cstdlib>
#include <ctype.h>
#include <cwctype>

#ifdef __cplusplus
extern "C" {
#endif

inline _LIBCPP_HIDE_FROM_ABI_C long strtol_l(const char* __nptr, char** __endptr, int __base, locale_t) {
  return ::strtol(__nptr, __endptr, __base);
}

inline _LIBCPP_HIDE_FROM_ABI_C unsigned long strtoul_l(const char* __nptr, char** __endptr, int __base, locale_t) {
  return ::strtoul(__nptr, __endptr, __base);
}

#ifdef __cplusplus
}
#endif

#endif
