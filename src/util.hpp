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

#if defined(_MSC_VER)

#include <intrin.h>  

#define ATTRIBUTE_COLD __declspec(noinline)
#define ATTRIBUTE_PRINTF(a, b)
#define ATTRIBUTE_RETURNS_NOALIAS __declspec(restrict)
#define ATTRIBUTE_NORETURN __declspec(noreturn)

#else

#define ATTRIBUTE_COLD         __attribute__((cold))
#define ATTRIBUTE_PRINTF(a, b) __attribute__((format(printf, a, b)))
#define ATTRIBUTE_RETURNS_NOALIAS __attribute__((__malloc__))
#define ATTRIBUTE_NORETURN __attribute__((noreturn))

#endif

#include "softfloat.hpp"

#define BREAKPOINT __asm("int $0x03")

ATTRIBUTE_COLD
ATTRIBUTE_NORETURN
ATTRIBUTE_PRINTF(1, 2)
void zig_panic(const char *format, ...);

#ifdef WIN32
#define __func__ __FUNCTION__
#endif

#define zig_unreachable() zig_panic("unreachable: %s:%s:%d", __FILE__, __func__, __LINE__)

#if defined(_MSC_VER)
static inline int clzll(unsigned long long mask) {
    unsigned long lz;
#if defined(_WIN64)
    if (_BitScanReverse64(&lz, mask))
        return static_cast<int>(63 - lz);
    zig_unreachable();
#else
    if (_BitScanReverse(&lz, mask >> 32))
        lz += 32;
    else
        _BitScanReverse(&lz, mask & 0xffffffff);
    return 63 - lz;
#endif
}
#else
#define clzll(x) __builtin_clzll(x)
#endif

template<typename T>
ATTRIBUTE_RETURNS_NOALIAS static inline T *allocate_nonzero(size_t count) {
#ifndef NDEBUG
    // make behavior when size == 0 portable
    if (count == 0)
        return nullptr;
#endif
    T *ptr = reinterpret_cast<T*>(malloc(count * sizeof(T)));
    if (!ptr)
        zig_panic("allocation failed");
    return ptr;
}

template<typename T>
ATTRIBUTE_RETURNS_NOALIAS static inline T *allocate(size_t count) {
#ifndef NDEBUG
    // make behavior when size == 0 portable
    if (count == 0)
        return nullptr;
#endif
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
static inline T *reallocate(T *old, size_t old_count, size_t new_count) {
    T *ptr = reallocate_nonzero(old, old_count, new_count);
    if (new_count > old_count) {
        memset(&ptr[old_count], 0, (new_count - old_count) * sizeof(T));
    }
    return ptr;
}

template<typename T>
static inline T *reallocate_nonzero(T *old, size_t old_count, size_t new_count) {
#ifndef NDEBUG
    // make behavior when size == 0 portable
    if (new_count == 0 && old == nullptr)
        return nullptr;
#endif
    T *ptr = reinterpret_cast<T*>(realloc(old, new_count * sizeof(T)));
    if (!ptr)
        zig_panic("allocation failed");
    return ptr;
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

static inline bool is_power_of_2(uint64_t x) {
    return x != 0 && ((x & (~x + 1)) == x);
}

uint32_t int_hash(int i);
bool int_eq(int a, int b);
uint32_t uint64_hash(uint64_t i);
bool uint64_eq(uint64_t a, uint64_t b);
uint32_t ptr_hash(const void *ptr);
bool ptr_eq(const void *a, const void *b);

static inline uint8_t log2_u64(uint64_t x) {
    return (63 - clzll(x));
}

static inline float16_t zig_double_to_f16(double x) {
    float64_t y;
    static_assert(sizeof(x) == sizeof(y), "");
    memcpy(&y, &x, sizeof(x));
    return f64_to_f16(y);
}


// Return value is safe to coerce to float even when |x| is NaN or Infinity.
static inline double zig_f16_to_double(float16_t x) {
    float64_t y = f16_to_f64(x);
    double z;
    static_assert(sizeof(y) == sizeof(z), "");
    memcpy(&z, &y, sizeof(y));
    return z;
}

#endif
