/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

#include "util.hpp"

void zig_panic(const char *format, ...) {
    va_list ap;
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    abort();
}

char *zig_alloc_sprintf(int *len, const char *format, ...) {
    va_list ap, ap2;
    va_start(ap, format);
    va_copy(ap2, ap);

    int len1 = vsnprintf(nullptr, 0, format, ap);
    assert(len1 >= 0);

    size_t required_size = len1 + 1;
    char *mem = allocate<char>(required_size);
    if (!mem)
        return nullptr;

    int len2 = vsnprintf(mem, required_size, format, ap2);
    assert(len2 == len1);

    va_end(ap2);
    va_end(ap);

    if (len)
        *len = len1;
    return mem;
}

