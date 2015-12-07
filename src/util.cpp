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

uint32_t int_hash(int i) {
    return *reinterpret_cast<uint32_t*>(&i);
}
bool int_eq(int a, int b) {
    return a == b;
}
