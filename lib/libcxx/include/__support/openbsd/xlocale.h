// -*- C++ -*-
//===-----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP_SUPPORT_OPENBSD_XLOCALE_H
#define _LIBCPP_SUPPORT_OPENBSD_XLOCALE_H

#include <__support/xlocale/__strtonum_fallback.h>
#include <clocale>
#include <cstdlib>
#include <ctype.h>
#include <cwctype>

#ifdef __cplusplus
extern "C" {
#endif


inline _LIBCPP_HIDE_FROM_ABI long
strtol_l(const char *nptr, char **endptr, int base, locale_t) {
  return ::strtol(nptr, endptr, base);
}

inline _LIBCPP_HIDE_FROM_ABI unsigned long
strtoul_l(const char *nptr, char **endptr, int base, locale_t) {
  return ::strtoul(nptr, endptr, base);
}


#ifdef __cplusplus
}
#endif

#endif
