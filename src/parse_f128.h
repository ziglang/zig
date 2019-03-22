/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_PARSE_F128_H
#define ZIG_PARSE_F128_H

#include "softfloat_types.h"

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

ZIG_EXTERN_C float128_t parse_f128(const char *s, char **p);

#endif
