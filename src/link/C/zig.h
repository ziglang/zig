#if __STDC_VERSION__ >= 201112L
#define zig_noreturn _Noreturn
#define zig_threadlocal thread_local
#elif __GNUC__
#define zig_noreturn __attribute__ ((noreturn))
#define zig_threadlocal __thread
#elif _MSC_VER
#define zig_noreturn __declspec(noreturn)
#define zig_threadlocal __declspec(thread)
#else
#define zig_noreturn
#define zig_threadlocal zig_threadlocal_unavailable
#endif

#if __GNUC__
#define ZIG_COLD __attribute__ ((cold))
#else
#define ZIG_COLD
#endif

#if __STDC_VERSION__ >= 199901L
#define ZIG_RESTRICT restrict
#elif defined(__GNUC__)
#define ZIG_RESTRICT __restrict
#else
#define ZIG_RESTRICT
#endif

#if __STDC_VERSION__ >= 201112L
#include <stdalign.h>
#define ZIG_ALIGN(alignment) alignas(alignment)
#elif defined(__GNUC__)
#define ZIG_ALIGN(alignment) __attribute__((aligned(alignment)))
#else
#define ZIG_ALIGN(alignment) zig_compile_error("the C compiler being used does not support aligning variables")
#endif

#if __STDC_VERSION__ >= 199901L
#include <stdbool.h>
#else
#define bool unsigned char
#define true 1
#define false 0
#endif

#if defined(__GNUC__)
#define zig_unreachable() __builtin_unreachable()
#else
#define zig_unreachable()
#endif

#ifdef __cplusplus
#define ZIG_EXTERN_C extern "C"
#else
#define ZIG_EXTERN_C
#endif

#if defined(_MSC_VER)
#define zig_breakpoint() __debugbreak()
#elif defined(__MINGW32__) || defined(__MINGW64__)
#define zig_breakpoint() __debugbreak()
#elif defined(__clang__)
#define zig_breakpoint() __builtin_debugtrap()
#elif defined(__GNUC__)
#define zig_breakpoint() __builtin_trap()
#elif defined(__i386__) || defined(__x86_64__)
#define zig_breakpoint() __asm__ volatile("int $0x03");
#else
#define zig_breakpoint() raise(SIGTRAP)
#endif

#if defined(_MSC_VER)
#define zig_return_address() _ReturnAddress()
#elif defined(__GNUC__)
#define zig_return_address() __builtin_extract_return_addr(__builtin_return_address(0))
#else
#define zig_return_address() 0
#endif

#if defined(__GNUC__)
#define zig_frame_address() __builtin_frame_address(0)
#else
#define zig_frame_address() 0
#endif

#if defined(__GNUC__)
#define zig_prefetch(addr, rw, locality) __builtin_prefetch(addr, rw, locality)
#else
#define zig_prefetch(addr, rw, locality)
#endif

#if defined(__clang__)
#define zig_wasm_memory_size(index) __builtin_wasm_memory_size(index)
#define zig_wasm_memory_grow(index, delta) __builtin_wasm_memory_grow(index, delta)
#else
#define zig_wasm_memory_size(index) zig_unimplemented()
#define zig_wasm_memory_grow(index, delta) zig_unimplemented()
#endif

#if __STDC_VERSION__ >= 201112L && !defined(__STDC_NO_ATOMICS__)
#include <stdatomic.h>
#define zig_cmpxchg_strong(obj, expected, desired, succ, fail) atomic_compare_exchange_strong_explicit(obj, &(expected), desired, succ, fail)
#define zig_cmpxchg_weak  (obj, expected, desired, succ, fail) atomic_compare_exchange_weak_explicit  (obj, &(expected), desired, succ, fail)
#define zig_atomicrmw_xchg(obj, arg, order) atomic_exchange_explicit  (obj, arg, order)
#define zig_atomicrmw_add (obj, arg, order) atomic_fetch_add_explicit (obj, arg, order)
#define zig_atomicrmw_sub (obj, arg, order) atomic_fetch_sub_explicit (obj, arg, order)
#define zig_atomicrmw_or  (obj, arg, order) atomic_fetch_or_explicit  (obj, arg, order)
#define zig_atomicrmw_xor (obj, arg, order) atomic_fetch_xor_explicit (obj, arg, order)
#define zig_atomicrmw_and (obj, arg, order) atomic_fetch_and_explicit (obj, arg, order)
#define zig_atomicrmw_nand(obj, arg, order) atomic_fetch_nand_explicit(obj, arg, order)
#define zig_atomicrmw_min (obj, arg, order) atomic_fetch_min_explicit (obj, arg, order)
#define zig_atomicrmw_max (obj, arg, order) atomic_fetch_max_explicit (obj, arg, order)
#define zig_atomic_store  (obj, arg, order) atomic_store_explicit     (obj, arg, order)
#define zig_atomic_load   (obj,      order) atomic_load_explicit      (obj,      order)
#define zig_fence(order) atomic_thread_fence(order)
#elif __GNUC__
#define memory_order_relaxed __ATOMIC_RELAXED
#define memory_order_consume __ATOMIC_CONSUME
#define memory_order_acquire __ATOMIC_ACQUIRE
#define memory_order_release __ATOMIC_RELEASE
#define memory_order_acq_rel __ATOMIC_ACQ_REL
#define memory_order_seq_cst __ATOMIC_SEQ_CST
#define zig_cmpxchg_strong(obj, expected, desired, succ, fail) __atomic_compare_exchange_n(obj, &(expected), desired, false, succ, fail)
#define zig_cmpxchg_weak  (obj, expected, desired, succ, fail) __atomic_compare_exchange_n(obj, &(expected), desired, true , succ, fail)
#define zig_atomicrmw_xchg(obj, arg, order) __atomic_exchange_n(obj, arg, order)
#define zig_atomicrmw_add (obj, arg, order) __atomic_fetch_add (obj, arg, order)
#define zig_atomicrmw_sub (obj, arg, order) __atomic_fetch_sub (obj, arg, order)
#define zig_atomicrmw_or  (obj, arg, order) __atomic_fetch_or  (obj, arg, order)
#define zig_atomicrmw_xor (obj, arg, order) __atomic_fetch_xor (obj, arg, order)
#define zig_atomicrmw_and (obj, arg, order) __atomic_fetch_and (obj, arg, order)
#define zig_atomicrmw_nand(obj, arg, order) __atomic_fetch_nand(obj, arg, order)
#define zig_atomicrmw_min (obj, arg, order) __atomic_fetch_min (obj, arg, order)
#define zig_atomicrmw_max (obj, arg, order) __atomic_fetch_max (obj, arg, order)
#define zig_atomic_store  (obj, arg, order) __atomic_store     (obj, arg, order)
#define zig_atomic_load   (obj,      order) __atomic_load      (obj,      order)
#define zig_fence(order) __atomic_thread_fence(order)
#else
#define memory_order_relaxed 0
#define memory_order_consume 1
#define memory_order_acquire 2
#define memory_order_release 3
#define memory_order_acq_rel 4
#define memory_order_seq_cst 5
#define zig_cmpxchg_strong(obj, expected, desired, succ, fail) zig_unimplemented()
#define zig_cmpxchg_weak  (obj, expected, desired, succ, fail) zig_unimplemented()
#define zig_atomicrmw_xchg(obj, arg, order) zig_unimplemented()
#define zig_atomicrmw_add (obj, arg, order) zig_unimplemented()
#define zig_atomicrmw_sub (obj, arg, order) zig_unimplemented()
#define zig_atomicrmw_or  (obj, arg, order) zig_unimplemented()
#define zig_atomicrmw_xor (obj, arg, order) zig_unimplemented()
#define zig_atomicrmw_and (obj, arg, order) zig_unimplemented()
#define zig_atomicrmw_nand(obj, arg, order) zig_unimplemented()
#define zig_atomicrmw_min (obj, arg, order) zig_unimplemented()
#define zig_atomicrmw_max (obj, arg, order) zig_unimplemented()
#define zig_atomic_store  (obj, arg, order) zig_unimplemented()
#define zig_atomic_load   (obj,      order) zig_unimplemented()
#define zig_fence(order) zig_unimplemented()
#endif

#include <stdint.h>
#include <stddef.h>
#include <limits.h>

#define int128_t __int128
#define uint128_t unsigned __int128
ZIG_EXTERN_C void *memcpy (void *ZIG_RESTRICT, const void *ZIG_RESTRICT, size_t);
ZIG_EXTERN_C void *memset (void *, int, size_t);

static inline uint8_t zig_addw_u8(uint8_t lhs, uint8_t rhs, uint8_t max) {
    uint8_t thresh = max - rhs;
    if (lhs > thresh) {
        return lhs - thresh - 1;
    } else {
        return lhs + rhs;
    }
}

static inline int8_t zig_addw_i8(int8_t lhs, int8_t rhs, int8_t min, int8_t max) {
    if ((lhs > 0) && (rhs > 0)) {
        int8_t thresh = max - rhs;
        if (lhs > thresh) {
            return min + lhs - thresh - 1;
        }
    } else if ((lhs < 0) && (rhs < 0)) {
        int8_t thresh = min - rhs;
        if (lhs < thresh) {
            return max + lhs - thresh + 1;
        }
    }
    return lhs + rhs;
}

static inline uint16_t zig_addw_u16(uint16_t lhs, uint16_t rhs, uint16_t max) {
    uint16_t thresh = max - rhs;
    if (lhs > thresh) {
        return lhs - thresh - 1;
    } else {
        return lhs + rhs;
    }
}

static inline int16_t zig_addw_i16(int16_t lhs, int16_t rhs, int16_t min, int16_t max) {
    if ((lhs > 0) && (rhs > 0)) {
        int16_t thresh = max - rhs;
        if (lhs > thresh) {
            return min + lhs - thresh - 1;
        }
    } else if ((lhs < 0) && (rhs < 0)) {
        int16_t thresh = min - rhs;
        if (lhs < thresh) {
            return max + lhs - thresh + 1;
        }
    }
    return lhs + rhs;
}

static inline uint32_t zig_addw_u32(uint32_t lhs, uint32_t rhs, uint32_t max) {
    uint32_t thresh = max - rhs;
    if (lhs > thresh) {
        return lhs - thresh - 1;
    } else {
        return lhs + rhs;
    }
}

static inline int32_t zig_addw_i32(int32_t lhs, int32_t rhs, int32_t min, int32_t max) {
    if ((lhs > 0) && (rhs > 0)) {
        int32_t thresh = max - rhs;
        if (lhs > thresh) {
            return min + lhs - thresh - 1;
        }
    } else if ((lhs < 0) && (rhs < 0)) {
        int32_t thresh = min - rhs;
        if (lhs < thresh) {
            return max + lhs - thresh + 1;
        }
    }
    return lhs + rhs;
}

static inline uint64_t zig_addw_u64(uint64_t lhs, uint64_t rhs, uint64_t max) {
    uint64_t thresh = max - rhs;
    if (lhs > thresh) {
        return lhs - thresh - 1;
    } else {
        return lhs + rhs;
    }
}

static inline int64_t zig_addw_i64(int64_t lhs, int64_t rhs, int64_t min, int64_t max) {
    if ((lhs > 0) && (rhs > 0)) {
        int64_t thresh = max - rhs;
        if (lhs > thresh) {
            return min + lhs - thresh - 1;
        }
    } else if ((lhs < 0) && (rhs < 0)) {
        int64_t thresh = min - rhs;
        if (lhs < thresh) {
            return max + lhs - thresh + 1;
        }
    }
    return lhs + rhs;
}

static inline intptr_t zig_addw_isize(intptr_t lhs, intptr_t rhs, intptr_t min, intptr_t max) {
    return (intptr_t)(((uintptr_t)lhs) + ((uintptr_t)rhs));
}

static inline short zig_addw_short(short lhs, short rhs, short min, short max) {
    return (short)(((unsigned short)lhs) + ((unsigned short)rhs));
}

static inline int zig_addw_int(int lhs, int rhs, int min, int max) {
    return (int)(((unsigned)lhs) + ((unsigned)rhs));
}

static inline long zig_addw_long(long lhs, long rhs, long min, long max) {
    return (long)(((unsigned long)lhs) + ((unsigned long)rhs));
}

static inline long long zig_addw_longlong(long long lhs, long long rhs, long long min, long long max) {
    return (long long)(((unsigned long long)lhs) + ((unsigned long long)rhs));
}

static inline uint8_t zig_subw_u8(uint8_t lhs, uint8_t rhs, uint8_t max) {
    if (lhs < rhs) {
        return max - rhs - lhs + 1;
    } else {
        return lhs - rhs;
    }
}

static inline int8_t zig_subw_i8(int8_t lhs, int8_t rhs, int8_t min, int8_t max) {
    if ((lhs > 0) && (rhs < 0)) {
        int8_t thresh = lhs - max;
        if (rhs < thresh) {
            return min + (thresh - rhs - 1);
        }
    } else if ((lhs < 0) && (rhs > 0)) {
        int8_t thresh = lhs - min;
        if (rhs > thresh) {
            return max - (rhs - thresh - 1);
        }
    }
    return lhs - rhs;
}

static inline uint16_t zig_subw_u16(uint16_t lhs, uint16_t rhs, uint16_t max) {
    if (lhs < rhs) {
        return max - rhs - lhs + 1;
    } else {
        return lhs - rhs;
    }
}

static inline int16_t zig_subw_i16(int16_t lhs, int16_t rhs, int16_t min, int16_t max) {
    if ((lhs > 0) && (rhs < 0)) {
        int16_t thresh = lhs - max;
        if (rhs < thresh) {
            return min + (thresh - rhs - 1);
        }
    } else if ((lhs < 0) && (rhs > 0)) {
        int16_t thresh = lhs - min;
        if (rhs > thresh) {
            return max - (rhs - thresh - 1);
        }
    }
    return lhs - rhs;
}

static inline uint32_t zig_subw_u32(uint32_t lhs, uint32_t rhs, uint32_t max) {
    if (lhs < rhs) {
        return max - rhs - lhs + 1;
    } else {
        return lhs - rhs;
    }
}

static inline int32_t zig_subw_i32(int32_t lhs, int32_t rhs, int32_t min, int32_t max) {
    if ((lhs > 0) && (rhs < 0)) {
        int32_t thresh = lhs - max;
        if (rhs < thresh) {
            return min + (thresh - rhs - 1);
        }
    } else if ((lhs < 0) && (rhs > 0)) {
        int32_t thresh = lhs - min;
        if (rhs > thresh) {
            return max - (rhs - thresh - 1);
        }
    }
    return lhs - rhs;
}

static inline uint64_t zig_subw_u64(uint64_t lhs, uint64_t rhs, uint64_t max) {
    if (lhs < rhs) {
        return max - rhs - lhs + 1;
    } else {
        return lhs - rhs;
    }
}

static inline int64_t zig_subw_i64(int64_t lhs, int64_t rhs, int64_t min, int64_t max) {
    if ((lhs > 0) && (rhs < 0)) {
        int64_t thresh = lhs - max;
        if (rhs < thresh) {
            return min + (thresh - rhs - 1);
        }
    } else if ((lhs < 0) && (rhs > 0)) {
        int64_t thresh = lhs - min;
        if (rhs > thresh) {
            return max - (rhs - thresh - 1);
        }
    }
    return lhs - rhs;
}

static inline intptr_t zig_subw_isize(intptr_t lhs, intptr_t rhs, intptr_t min, intptr_t max) {
    return (intptr_t)(((uintptr_t)lhs) - ((uintptr_t)rhs));
}

static inline short zig_subw_short(short lhs, short rhs, short min, short max) {
    return (short)(((unsigned short)lhs) - ((unsigned short)rhs));
}

static inline int zig_subw_int(int lhs, int rhs, int min, int max) {
    return (int)(((unsigned)lhs) - ((unsigned)rhs));
}

static inline long zig_subw_long(long lhs, long rhs, long min, long max) {
    return (long)(((unsigned long)lhs) - ((unsigned long)rhs));
}

static inline long long zig_subw_longlong(long long lhs, long long rhs, long long min, long long max) {
    return (long long)(((unsigned long long)lhs) - ((unsigned long long)rhs));
}

static inline float zig_bitcast_f32_u32(uint32_t arg) {
    float dest;
    memcpy(&dest, &arg, sizeof dest);
    return dest;
}

static inline float zig_bitcast_f64_u64(uint64_t arg) {
    double dest;
    memcpy(&dest, &arg, sizeof dest);
    return dest;
}

#define zig_add_sat_u(ZT, T) static inline T zig_adds_##ZT(T x, T y, T max) { \
    return (x > max - y) ? max : x + y; \
}

#define zig_add_sat_s(ZT, T, T2) static inline T zig_adds_##ZT(T2 x, T2 y, T2 min, T2 max) { \
    T2 res = x + y; \
    return (res < min) ? min : (res > max) ? max : res; \
}

zig_add_sat_u( u8,    uint8_t)
zig_add_sat_s( i8,     int8_t,  int16_t)
zig_add_sat_u(u16,   uint16_t)
zig_add_sat_s(i16,    int16_t,  int32_t)
zig_add_sat_u(u32,   uint32_t)
zig_add_sat_s(i32,    int32_t,  int64_t)
zig_add_sat_u(u64,   uint64_t)
zig_add_sat_s(i64,    int64_t, int128_t)
zig_add_sat_s(isize, intptr_t, int128_t)
zig_add_sat_s(short,    short, int)
zig_add_sat_s(int,        int, long)
zig_add_sat_s(long,      long, long long)

#define zig_sub_sat_u(ZT, T) static inline T zig_subs_##ZT(T x, T y, T max) { \
    return (x > max + y) ? max : x - y; \
}

#define zig_sub_sat_s(ZT, T, T2) static inline T zig_subs_##ZT(T2 x, T2 y, T2 min, T2 max) { \
    T2 res = x - y; \
    return (res < min) ? min : (res > max) ? max : res; \
}

zig_sub_sat_u( u8,    uint8_t)
zig_sub_sat_s( i8,     int8_t,  int16_t)
zig_sub_sat_u(u16,   uint16_t)
zig_sub_sat_s(i16,    int16_t,  int32_t)
zig_sub_sat_u(u32,   uint32_t)
zig_sub_sat_s(i32,    int32_t,  int64_t)
zig_sub_sat_u(u64,   uint64_t)
zig_sub_sat_s(i64,    int64_t, int128_t)
zig_sub_sat_s(isize, intptr_t, int128_t)
zig_sub_sat_s(short,    short, int)
zig_sub_sat_s(int,        int, long)
zig_sub_sat_s(long,      long, long long)


#define zig_mul_sat_u(ZT, T, T2) static inline T zig_muls_##ZT(T2 x, T2 y, T2 max) { \
    T2 res = x * y; \
    return (res > max) ? max : res; \
}

#define zig_mul_sat_s(ZT, T, T2) static inline T zig_muls_##ZT(T2 x, T2 y, T2 min, T2 max) { \
    T2 res = x * y; \
    return (res < min) ? min : (res > max) ? max : res; \
}

zig_mul_sat_u(u8,    uint8_t,   uint16_t)
zig_mul_sat_s(i8,     int8_t,    int16_t)
zig_mul_sat_u(u16,   uint16_t,  uint32_t)
zig_mul_sat_s(i16,    int16_t,   int32_t)
zig_mul_sat_u(u32,   uint32_t,  uint64_t)
zig_mul_sat_s(i32,    int32_t,   int64_t)
zig_mul_sat_u(u64,   uint64_t, uint128_t)
zig_mul_sat_s(i64,    int64_t,  int128_t)
zig_mul_sat_s(isize, intptr_t,  int128_t)
zig_mul_sat_s(short,    short, int)
zig_mul_sat_s(int,        int, long)
zig_mul_sat_s(long,      long, long long)

#define zig_shl_sat_u(ZT, T, bits) static inline T zig_shls_##ZT(T x, T y, T max) { \
    if(x == 0) return 0; \
    T bits_set = 64 - __builtin_clzll(x); \
    return (bits_set + y > bits) ? max : x << y; \
}

#define zig_shl_sat_s(ZT, T, bits) static inline T zig_shls_##ZT(T x, T y, T min, T max) { \
    if(x == 0) return 0; \
    T x_twos_comp = x < 0 ? -x : x; \
    T bits_set = 64 - __builtin_clzll(x_twos_comp); \
    T min_or_max = (x < 0) ? min : max; \
    return (y + bits_set > bits ) ?  min_or_max : x << y; \
}

zig_shl_sat_u(u8,     uint8_t, 8)
zig_shl_sat_s(i8,      int8_t, 7)
zig_shl_sat_u(u16,   uint16_t, 16)
zig_shl_sat_s(i16,    int16_t, 15)
zig_shl_sat_u(u32,   uint32_t, 32)
zig_shl_sat_s(i32,    int32_t, 31)
zig_shl_sat_u(u64,   uint64_t, 64)
zig_shl_sat_s(i64,    int64_t, 63)
zig_shl_sat_s(isize, intptr_t, ((sizeof(intptr_t)) * CHAR_BIT - 1))
zig_shl_sat_s(short,    short, ((sizeof(short   )) * CHAR_BIT - 1))
zig_shl_sat_s(int,        int, ((sizeof(int     )) * CHAR_BIT - 1))
zig_shl_sat_s(long,      long, ((sizeof(long    )) * CHAR_BIT - 1))

#define zig_bitsizeof(T) (CHAR_BIT * sizeof(T))
#define zig_bit_mask(T, bit_width) \
    ((bit_width) == 128 \
     ? ((T)(((uint128_t) 0xffffffffffffffff) << 64 | \
             (uint128_t) 0xffffffffffffffff)) \
     : (((T)1 << (T)(bit_width)) - 1))

static inline uint128_t zig_sign_extend(uint128_t value, uint128_t zig_type_bit_width) {
    const uint128_t m = (uint128_t)1 << (zig_type_bit_width - 1);
    return (value ^ m) - m;
}

static inline int zig_clz(unsigned long long value, uint8_t zig_type_bit_width, bool signed_type) {
    (void)signed_type; // unused

    if (value == 0) return zig_type_bit_width;
    if (zig_type_bit_width <= zig_bitsizeof(unsigned int))
        return (__builtin_clz(value) - zig_bitsizeof(unsigned int) + zig_type_bit_width);
    if (zig_type_bit_width <= zig_bitsizeof(unsigned long))
        return (__builtin_clzl(value) - zig_bitsizeof(unsigned long) + zig_type_bit_width);
    return (__builtin_clzll(value) - zig_bitsizeof(unsigned long long) + zig_type_bit_width);
}

static inline int zig_ctz(unsigned long long value, uint8_t zig_type_bit_width, bool signed_type) {
    (void)signed_type; // unused

    if (value == 0) return zig_type_bit_width;
    if (zig_type_bit_width <= zig_bitsizeof(unsigned int)) return __builtin_ctz(value);
    if (zig_type_bit_width <= zig_bitsizeof(unsigned long)) return __builtin_ctzl(value);
    return __builtin_ctzll(value);
}

static inline int zig_popcount(unsigned long long value, uint8_t zig_type_bit_width, bool signed_type) {
    (void)signed_type; // unused

    const unsigned long long mask = zig_bit_mask(unsigned long long, zig_type_bit_width);
    if (zig_type_bit_width <= zig_bitsizeof(unsigned int))
        return __builtin_popcount(value & mask);
    if (zig_type_bit_width <= zig_bitsizeof(unsigned long))
        return __builtin_popcountl(value & mask);
    return __builtin_popcountll(value & mask);
}

static inline uint128_t zig_byte_swap(uint128_t value, uint8_t zig_type_bit_width, bool signed_type) {
    if (zig_type_bit_width <= 8)  return value;
    if (zig_type_bit_width <= 16) return __builtin_bswap16(value);
    if (zig_type_bit_width <= 32) {
        const uint32_t swapped = __builtin_bswap32(value) >> (32 - zig_type_bit_width);
        return (signed_type ? zig_sign_extend(swapped, zig_type_bit_width) : swapped);
    }
    if (zig_type_bit_width <= 64) {
        const uint64_t swapped = __builtin_bswap64(value) >> (64 - zig_type_bit_width);
        return (signed_type ? zig_sign_extend(swapped, zig_type_bit_width) : swapped);
    }
    const uint128_t mask = zig_bit_mask(uint128_t, zig_type_bit_width);
    const uint128_t hi = __builtin_bswap64((uint64_t)(value >> 64));
    const uint128_t lo = __builtin_bswap64((uint64_t)value);
    const uint128_t swapped = (((lo << 64 | hi) >> (128 - zig_type_bit_width))) & mask;
    return (signed_type ? zig_sign_extend(swapped, zig_type_bit_width) : swapped);
}

static inline uint128_t zig_bit_reverse(uint128_t value, uint8_t zig_type_bit_width, bool signed_type) {
    static const uint128_t reverse_lut[256] = {
        0x00, 0x80, 0x40, 0xc0, 0x20, 0xa0, 0x60, 0xe0, 0x10, 0x90, 0x50, 0xd0,
        0x30, 0xb0, 0x70, 0xf0, 0x08, 0x88, 0x48, 0xc8, 0x28, 0xa8, 0x68, 0xe8,
        0x18, 0x98, 0x58, 0xd8, 0x38, 0xb8, 0x78, 0xf8, 0x04, 0x84, 0x44, 0xc4,
        0x24, 0xa4, 0x64, 0xe4, 0x14, 0x94, 0x54, 0xd4, 0x34, 0xb4, 0x74, 0xf4,
        0x0c, 0x8c, 0x4c, 0xcc, 0x2c, 0xac, 0x6c, 0xec, 0x1c, 0x9c, 0x5c, 0xdc,
        0x3c, 0xbc, 0x7c, 0xfc, 0x02, 0x82, 0x42, 0xc2, 0x22, 0xa2, 0x62, 0xe2,
        0x12, 0x92, 0x52, 0xd2, 0x32, 0xb2, 0x72, 0xf2, 0x0a, 0x8a, 0x4a, 0xca,
        0x2a, 0xaa, 0x6a, 0xea, 0x1a, 0x9a, 0x5a, 0xda, 0x3a, 0xba, 0x7a, 0xfa,
        0x06, 0x86, 0x46, 0xc6, 0x26, 0xa6, 0x66, 0xe6, 0x16, 0x96, 0x56, 0xd6,
        0x36, 0xb6, 0x76, 0xf6, 0x0e, 0x8e, 0x4e, 0xce, 0x2e, 0xae, 0x6e, 0xee,
        0x1e, 0x9e, 0x5e, 0xde, 0x3e, 0xbe, 0x7e, 0xfe, 0x01, 0x81, 0x41, 0xc1,
        0x21, 0xa1, 0x61, 0xe1, 0x11, 0x91, 0x51, 0xd1, 0x31, 0xb1, 0x71, 0xf1,
        0x09, 0x89, 0x49, 0xc9, 0x29, 0xa9, 0x69, 0xe9, 0x19, 0x99, 0x59, 0xd9,
        0x39, 0xb9, 0x79, 0xf9, 0x05, 0x85, 0x45, 0xc5, 0x25, 0xa5, 0x65, 0xe5,
        0x15, 0x95, 0x55, 0xd5, 0x35, 0xb5, 0x75, 0xf5, 0x0d, 0x8d, 0x4d, 0xcd,
        0x2d, 0xad, 0x6d, 0xed, 0x1d, 0x9d, 0x5d, 0xdd, 0x3d, 0xbd, 0x7d, 0xfd,
        0x03, 0x83, 0x43, 0xc3, 0x23, 0xa3, 0x63, 0xe3, 0x13, 0x93, 0x53, 0xd3,
        0x33, 0xb3, 0x73, 0xf3, 0x0b, 0x8b, 0x4b, 0xcb, 0x2b, 0xab, 0x6b, 0xeb,
        0x1b, 0x9b, 0x5b, 0xdb, 0x3b, 0xbb, 0x7b, 0xfb, 0x07, 0x87, 0x47, 0xc7,
        0x27, 0xa7, 0x67, 0xe7, 0x17, 0x97, 0x57, 0xd7, 0x37, 0xb7, 0x77, 0xf7,
        0x0f, 0x8f, 0x4f, 0xcf, 0x2f, 0xaf, 0x6f, 0xef, 0x1f, 0x9f, 0x5f, 0xdf,
        0x3f, 0xbf, 0x7f, 0xff
    };
    const uint128_t mask = zig_bit_mask(uint128_t, zig_type_bit_width);
    const uint128_t swapped = zig_byte_swap(value, zig_type_bit_width, signed_type);
    const uint128_t reversed = (
        (reverse_lut[(swapped >> 0x78) & 0xff] << 0x78) |
        (reverse_lut[(swapped >> 0x70) & 0xff] << 0x70) |
        (reverse_lut[(swapped >> 0x68) & 0xff] << 0x68) |
        (reverse_lut[(swapped >> 0x60) & 0xff] << 0x60) |
        (reverse_lut[(swapped >> 0x58) & 0xff] << 0x58) |
        (reverse_lut[(swapped >> 0x50) & 0xff] << 0x50) |
        (reverse_lut[(swapped >> 0x48) & 0xff] << 0x48) |
        (reverse_lut[(swapped >> 0x40) & 0xff] << 0x40) |
        (reverse_lut[(swapped >> 0x38) & 0xff] << 0x38) |
        (reverse_lut[(swapped >> 0x30) & 0xff] << 0x30) |
        (reverse_lut[(swapped >> 0x28) & 0xff] << 0x28) |
        (reverse_lut[(swapped >> 0x20) & 0xff] << 0x20) |
        (reverse_lut[(swapped >> 0x18) & 0xff] << 0x18) |
        (reverse_lut[(swapped >> 0x10) & 0xff] << 0x10) |
        (reverse_lut[(swapped >> 0x08) & 0xff] << 0x08) |
        (reverse_lut[(swapped >> 0x00) & 0xff] << 0x00));
    const uint128_t result =
        (reversed >> (zig_type_bit_width < 8 ? 8 - zig_type_bit_width : 0)) & mask;
    return (signed_type ? zig_sign_extend(result, zig_type_bit_width) : result);
}
