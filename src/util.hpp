/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_UTIL_HPP
#define ZIG_UTIL_HPP

#include <stdlib.h>
#include <string.h>
#include <assert.h>

void zig_panic(const char *format, ...)
    __attribute__((cold))
    __attribute__ ((noreturn))
    __attribute__ ((format (printf, 1, 2)));

template<typename T>
__attribute__((malloc)) static inline T *allocate_nonzero(size_t count) {
    T *ptr = reinterpret_cast<T*>(malloc(count * sizeof(T)));
    if (!ptr)
        zig_panic("allocation failed");
    return ptr;
}

template<typename T>
__attribute__((malloc)) static inline T *allocate(size_t count) {
    T *ptr = reinterpret_cast<T*>(calloc(count, sizeof(T)));
    if (!ptr)
        zig_panic("allocation failed");
    return ptr;
}

template<typename T>
static inline T *reallocate_nonzero(T * old, size_t new_count) {
    T *ptr = reinterpret_cast<T*>(realloc(old, new_count * sizeof(T)));
    if (!ptr)
        zig_panic("allocation failed");
    return ptr;
}

char *zig_alloc_sprintf(int *len, const char *format, ...)
    __attribute__ ((format (printf, 2, 3)));

template <typename T, long n>
constexpr long array_length(const T (&)[n]) {
    return n;
}
#endif
