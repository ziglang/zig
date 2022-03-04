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
