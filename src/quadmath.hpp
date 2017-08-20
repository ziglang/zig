/*
 * Copyright (c) 2017 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_QUADMATH_HPP
#define ZIG_QUADMATH_HPP

extern "C" {
    __float128 fmodq(__float128 a, __float128 b);
    __float128 ceilq(__float128 a);
    __float128 floorq(__float128 a);
    __float128 strtoflt128 (const char *s, char **sp);
    int quadmath_snprintf (char *s, size_t size, const char *format, ...);
}

#endif
