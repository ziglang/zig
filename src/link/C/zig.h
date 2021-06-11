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
#define int128_t __int128
#define uint128_t unsigned __int128
ZIG_EXTERN_C void *memcpy (void *ZIG_RESTRICT, const void *ZIG_RESTRICT, size_t);

