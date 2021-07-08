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

#include <stdint.h>
#include <stddef.h>
#include <limits.h>
#define int128_t __int128
#define uint128_t unsigned __int128
ZIG_EXTERN_C void *memcpy (void *ZIG_RESTRICT, const void *ZIG_RESTRICT, size_t);

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

