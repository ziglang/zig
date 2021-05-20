// -*- C++ -*-
//===-----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP_SUPPORT_ANDROID_LOCALE_BIONIC_H
#define _LIBCPP_SUPPORT_ANDROID_LOCALE_BIONIC_H

#if defined(__BIONIC__)

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>
#include <xlocale.h>

#ifdef __cplusplus
}
#endif

#if defined(__ANDROID__)

#include <android/api-level.h>
#include <android/ndk-version.h>
#if __ANDROID_API__ < 21
#include <__support/xlocale/__posix_l_fallback.h>
#endif
// In NDK versions later than 16, locale-aware functions are provided by
// legacy_stdlib_inlines.h
#if __NDK_MAJOR__ <= 16
#if __ANDROID_API__ < 21
#include <__support/xlocale/__strtonum_fallback.h>
#elif __ANDROID_API__ < 26

#if defined(__cplusplus)
extern "C" {
#endif

inline _LIBCPP_INLINE_VISIBILITY float strtof_l(const char* __nptr, char** __endptr,
                                                locale_t) {
  return ::strtof(__nptr, __endptr);
}

inline _LIBCPP_INLINE_VISIBILITY double strtod_l(const char* __nptr,
                                                 char** __endptr, locale_t) {
  return ::strtod(__nptr, __endptr);
}

inline _LIBCPP_INLINE_VISIBILITY long strtol_l(const char* __nptr, char** __endptr,
                                               int __base, locale_t) {
  return ::strtol(__nptr, __endptr, __base);
}

#if defined(__cplusplus)
}
#endif

#endif // __ANDROID_API__ < 26

#endif // __NDK_MAJOR__ <= 16
#endif // defined(__ANDROID__)

#endif // defined(__BIONIC__)
#endif // _LIBCPP_SUPPORT_ANDROID_LOCALE_BIONIC_H
