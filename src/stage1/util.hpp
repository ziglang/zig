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
#include <ctype.h>

#if defined(_MSC_VER)
#include <intrin.h>  
#endif

#define ZIG_Q(x) #x
#define ZIG_QUOTE(x) ZIG_Q(x)

#include "util_base.hpp"
#include "heap.hpp"
#include "mem.hpp"

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
static inline int ctzll(unsigned long long mask) {
    unsigned long result;
#if defined(_WIN64)
    if (_BitScanForward64(&result, mask))
        return result;
    zig_unreachable();
#else
    if (_BitScanForward(&result, mask & 0xffffffff))
        return result;
    if (_BitScanForward(&result, mask >> 32))
        return 32 + result;
    zig_unreachable();
#endif
}
#else
#define clzll(x) __builtin_clzll(x)
#define ctzll(x) __builtin_ctzll(x)
#endif

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

static inline bool mem_eql_mem(const char *a_ptr, size_t a_len, const char *b_ptr, size_t b_len) {
    if (a_len != b_len)
        return false;
    return memcmp(a_ptr, b_ptr, a_len) == 0;
}
static inline bool mem_eql_mem_ignore_case(const char *a_ptr, size_t a_len, const char *b_ptr, size_t b_len) {
    if (a_len != b_len)
        return false;
    for (size_t i = 0; i < a_len; i += 1) {
        if (tolower(a_ptr[i]) != tolower(b_ptr[i]))
            return false;
    }
    return true;
}

static inline bool mem_eql_str(const char *mem, size_t mem_len, const char *str) {
    return mem_eql_mem(mem, mem_len, str, strlen(str));
}

static inline bool str_eql_str(const char *a, const char* b) {
    return mem_eql_mem(a, strlen(a), b, strlen(b));
}

static inline bool str_eql_str_ignore_case(const char *a, const char* b) {
    return mem_eql_mem_ignore_case(a, strlen(a), b, strlen(b));
}

static inline bool is_power_of_2(uint64_t x) {
    return x != 0 && ((x & (~x + 1)) == x);
}

static inline bool mem_ends_with_mem(const char *mem, size_t mem_len, const char *end, size_t end_len) {
    if (mem_len < end_len) return false;
    return memcmp(mem + mem_len - end_len, end, end_len) == 0;
}

static inline bool mem_ends_with_str(const char *mem, size_t mem_len, const char *str) {
    return mem_ends_with_mem(mem, mem_len, str, strlen(str));
}

static inline uint64_t round_to_next_power_of_2(uint64_t x) {
    --x;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    x |= x >> 32;
    return x + 1;
}

static inline uint8_t log2_u64(uint64_t x) {
    return (63 - clzll(x));
}

void zig_pretty_print_bytes(FILE *f, double n);

template<typename T>
struct Optional {
    T value;
    bool is_some;

    static inline Optional<T> some(T x) {
        return {x, true};
    }

    static inline Optional<T> none() {
        return {{}, false};
    }

    inline bool unwrap(T *res) {
        *res = value;
        return is_some;
    }
};

template<typename T>
struct Slice {
    T *ptr;
    size_t len;

    inline T &at(size_t i) {
        assert(i < len);
        return ptr[i];
    }

    inline Slice<T> slice(size_t start, size_t end) {
        assert(end <= len);
        assert(end >= start);
        return {
            ptr + start,
            end - start,
        };
    }

    inline Slice<T> sliceFrom(size_t start) {
        assert(start <= len);
        return {
            ptr + start,
            len - start,
        };
    }

    static inline Slice<T> alloc(size_t n) {
        return {heap::c_allocator.allocate_nonzero<T>(n), n};
    }
};

template<typename T, size_t n>
struct Array {
    static const size_t len = n;
    T items[n];

    inline Slice<T> slice() {
        return {
            &items[0],
            len,
        };
    }
};

static inline Slice<uint8_t> str(const char *literal) {
    return {(uint8_t*)(literal), strlen(literal)};
}

// Ported from std/mem.zig
template<typename T>
static inline bool memEql(Slice<T> a, Slice<T> b) {
    if (a.len != b.len)
        return false;
    for (size_t i = 0; i < a.len; i += 1) {
        if (a.ptr[i] != b.ptr[i])
            return false;
    }
    return true;
}

// Ported from std/mem.zig
template<typename T>
static inline bool memStartsWith(Slice<T> haystack, Slice<T> needle) {
    if (needle.len > haystack.len)
        return false;
    return memEql(haystack.slice(0, needle.len), needle);
}

// Ported from std/mem.zig
template<typename T>
static inline void memCopy(Slice<T> dest, Slice<T> src) {
    assert(dest.len >= src.len);
    memcpy(dest.ptr, src.ptr, src.len * sizeof(T));
}

// Ported from std/mem.zig.
// Coordinate struct fields with memSplit function
struct SplitIterator {
    size_t index;
    Slice<uint8_t> buffer;
    Slice<uint8_t> split_bytes;
};

bool SplitIterator_isSplitByte(SplitIterator *self, uint8_t byte);
Optional< Slice<uint8_t> > SplitIterator_next(SplitIterator *self);
Optional< Slice<uint8_t> > SplitIterator_next_separate(SplitIterator *self);
Slice<uint8_t> SplitIterator_rest(SplitIterator *self);
SplitIterator memSplit(Slice<uint8_t> buffer, Slice<uint8_t> split_bytes);

#endif
