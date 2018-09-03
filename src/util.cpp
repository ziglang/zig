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
    fflush(stderr);
    va_end(ap);
    abort();
}

uint32_t int_hash(int i) {
    return (uint32_t)(i % UINT32_MAX);
}
bool int_eq(int a, int b) {
    return a == b;
}

uint32_t uint64_hash(uint64_t i) {
    return (uint32_t)(i % UINT32_MAX);
}

bool uint64_eq(uint64_t a, uint64_t b) {
    return a == b;
}

uint32_t ptr_hash(const void *ptr) {
    return (uint32_t)(((uintptr_t)ptr) % UINT32_MAX);
}

bool ptr_eq(const void *a, const void *b) {
    return a == b;
}

size_t levenshtein(const char *s, size_t ls, const char *t, size_t lt) {
    size_t a, b, c;
    if (!ls) return lt;
    if (!lt) return ls;
    if (s[ls] == t[ls]) return levenshtein(s, ls - 1, t, lt - 1);

    a = levenshtein(s, ls - 1, t, lt - 1);
    b = levenshtein(s, ls,     t, lt - 1);
    c = levenshtein(s, ls - 1, t, lt    );

    if (a > b) a = b;
    if (a > c) a = c;

    return a + 1;
}