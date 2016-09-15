/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_UTIL_HPP
#define ZIG_UTIL_HPP

#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include <new>

#define BREAKPOINT __asm("int $0x03")

void zig_panic(const char *format, ...)
    __attribute__((cold))
    __attribute__ ((noreturn))
    __attribute__ ((format (printf, 1, 2)));

__attribute__((cold))
__attribute__ ((noreturn))
static inline void zig_unreachable(void) {
    zig_panic("unreachable");
}

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
static inline void safe_memcpy(T *dest, const T *src, size_t count) {
#ifdef NDEBUG
    memcpy(dest, src, count * sizeof(T));
#else
    // manually assign every elment to trigger compile error for non-copyable structs
    for (size_t i = 0; i < count; i += 1) {
        dest[i] = src[i];
    }
#endif
}

template<typename T>
static inline T *reallocate_nonzero(T *old, size_t old_count, size_t new_count) {
#ifdef NDEBUG
    T *ptr = reinterpret_cast<T*>(realloc(old, new_count * sizeof(T)));
    if (!ptr)
        zig_panic("allocation failed");
    return ptr;
#else
    // manually assign every element to trigger compile error for non-copyable structs
    T *ptr = allocate_nonzero<T>(new_count);
    safe_memcpy(ptr, old, old_count);
    free(old);
    return ptr;
#endif
}

template <typename T, size_t n>
constexpr size_t array_length(const T (&)[n]) {
    return n;
}

template <typename T>
static inline T max(T a, T b) {
    return (a >= b) ? a : b;
}

template <typename T>
static inline T min(T a, T b) {
    return (a <= b) ? a : b;
}

template<typename T>
static inline T clamp(T min_value, T value, T max_value) {
    return max(min(value, max_value), min_value);
}

static inline bool mem_eql_str(const char *mem, size_t mem_len, const char *str) {
    size_t str_len = strlen(str);
    if (str_len != mem_len)
        return false;
    return memcmp(mem, str, mem_len) == 0;
}

uint32_t int_hash(int i);
bool int_eq(int a, int b);
uint32_t uint64_hash(uint64_t i);
bool uint64_eq(uint64_t a, uint64_t b);
uint32_t ptr_hash(const void *ptr);
bool ptr_eq(const void *a, const void *b);

#endif
