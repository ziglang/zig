/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_USERLAND_H
#define ZIG_USERLAND_H

#include <stddef.h>

#ifdef __cplusplus
#define ZIG_USERLAND_EXTERN_C extern "C"
#else
#define ZIG_USERLAND_EXTERN_C
#endif

ZIG_USERLAND_EXTERN_C void stage2_translate_c(void);

ZIG_USERLAND_EXTERN_C void stage2_zen(const char **ptr, size_t *len);

ZIG_USERLAND_EXTERN_C void stage2_panic(const char *ptr, size_t len);

#endif
