#if __STDC_VERSION__ >= 199901L
#include <stdbool.h>
#else
#define bool unsigned char
#define true 1
#define false 0
#endif

#if __STDC_VERSION__ >= 201112L
#define zig_noreturn _Noreturn
#elif __GNUC__
#define zig_noreturn __attribute__ ((noreturn))
#elif _MSC_VER
#define zig_noreturn __declspec(noreturn)
#else
#define zig_noreturn
#endif

#if defined(__GNUC__)
#define zig_unreachable() __builtin_unreachable()
#else
#define zig_unreachable()
#endif

#if defined(_MSC_VER)
#define zig_breakpoint __debugbreak()
#else
#if defined(__MINGW32__) || defined(__MINGW64__)
#define zig_breakpoint __debugbreak()
#elif defined(__clang__)
#define zig_breakpoint __builtin_debugtrap()
#elif defined(__GNUC__)
#define zig_breakpoint __builtin_trap()
#elif defined(__i386__) || defined(__x86_64__)
#define zig_breakpoint __asm__ volatile("int $0x03");
#else
#define zig_breakpoint raise(SIGTRAP)
#endif
#endif

#include <stdint.h>
#define int128_t __int128
#define uint128_t unsigned __int128

