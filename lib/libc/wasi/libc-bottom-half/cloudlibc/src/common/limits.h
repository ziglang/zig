// Copyright (c) 2015 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#ifndef COMMON_LIMITS_H
#define COMMON_LIMITS_H

#include <limits.h>

#define NUMERIC_MIN(t)                                  \
  _Generic((t)0, char                                   \
           : CHAR_MIN, signed char                      \
           : SCHAR_MIN, unsigned char : 0, short        \
           : SHRT_MIN, unsigned short : 0, int          \
           : INT_MIN, unsigned int : 0, long            \
           : LONG_MIN, unsigned long : 0, long long     \
           : LLONG_MIN, unsigned long long : 0, default \
           : (void)0)

#define NUMERIC_MAX(t)                     \
  _Generic((t)0, char                      \
           : CHAR_MAX, signed char         \
           : SCHAR_MAX, unsigned char      \
           : UCHAR_MAX, short              \
           : SHRT_MAX, unsigned short      \
           : USHRT_MAX, int                \
           : INT_MAX, unsigned int         \
           : UINT_MAX, long                \
           : LONG_MAX, unsigned long       \
           : ULONG_MAX, long long          \
           : LLONG_MAX, unsigned long long \
           : ULLONG_MAX, default           \
           : (void)0)

#endif
