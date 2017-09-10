/*
 * Copyright (c) 2017 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_QUADMATH_HPP
#define ZIG_QUADMATH_HPP

#if defined(_MSVC)
    #include <stdlib.h>
    #include <stdio.h>
    #include <stdarg.h>
    #include <cmath>
#endif

extern "C" {
#if defined(_MSVC)
    static __float128 fmodq(__float128 a, __float128 b)
    {
        return fmod(a, b);
    }
    static __float128 ceilq(__float128 a)
    {
        return ceil(a);
    }
    static __float128 floorq(__float128 a)
    {
        return floor(a);
    }
    static __float128 strtoflt128(const char *s, char **sp)
    {
        return strtold(s, sp);
    }
    static int quadmath_snprintf(char *s, size_t size, const char *format, ...)
    {
        va_list args;
        va_start(format, args);
        int result = vsnprintf(s, size, format, args);
        va_end(args);
        return result;
    }
#else
    __float128 fmodq(__float128 a, __float128 b);
    __float128 ceilq(__float128 a);
    __float128 floorq(__float128 a);
    __float128 strtoflt128 (const char *s, char **sp);
    int quadmath_snprintf (char *s, size_t size, const char *format, ...);
#endif
}

#endif
