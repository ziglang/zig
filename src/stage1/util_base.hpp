/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_UTIL_BASE_HPP
#define ZIG_UTIL_BASE_HPP

#include <assert.h>

#if defined(_MSC_VER)

#define ATTRIBUTE_COLD __declspec(noinline)
#define ATTRIBUTE_PRINTF(a, b)
#define ATTRIBUTE_RETURNS_NOALIAS __declspec(restrict)
#define ATTRIBUTE_NORETURN __declspec(noreturn)
#define ATTRIBUTE_MUST_USE

#define BREAKPOINT __debugbreak()

#else

#define ATTRIBUTE_COLD         __attribute__((cold))
#define ATTRIBUTE_PRINTF(a, b) __attribute__((format(printf, a, b)))
#define ATTRIBUTE_RETURNS_NOALIAS __attribute__((__malloc__))
#define ATTRIBUTE_NORETURN __attribute__((noreturn))
#define ATTRIBUTE_MUST_USE __attribute__((warn_unused_result))

#if defined(__MINGW32__) || defined(__MINGW64__)
#define BREAKPOINT __debugbreak()
#elif defined(__i386__) || defined(__x86_64__)
#define BREAKPOINT __asm__ volatile("int $0x03");
#elif defined(__clang__)
#define BREAKPOINT __builtin_debugtrap()
#elif defined(__GNUC__)
#define BREAKPOINT __builtin_trap()
#else
#include <signal.h>
#define BREAKPOINT raise(SIGTRAP)
#endif

#endif

ATTRIBUTE_COLD
ATTRIBUTE_NORETURN
ATTRIBUTE_PRINTF(1, 2)
void zig_panic(const char *format, ...);

static inline void zig_assert(bool ok, const char *file, int line, const char *func) {
    if (!ok) {
        zig_panic("Assertion failed at %s:%d in %s. This is a bug in the Zig compiler.", file, line, func);
    }
}

#ifdef _WIN32
#define __func__ __FUNCTION__
#endif

#define zig_unreachable() zig_panic("Unreachable at %s:%d in %s. This is a bug in the Zig compiler.", __FILE__, __LINE__, __func__)

// Assertions in stage1 are always on, and they call zig @panic.
#undef assert
#define assert(ok) zig_assert(ok, __FILE__, __LINE__, __func__)

#if defined(_MSC_VER)
#define ZIG_FALLTHROUGH
#elif defined(__clang__)
#define ZIG_FALLTHROUGH [[clang::fallthrough]]
#elif defined(__GNUC__) && __GNUC__ >= 7
#define ZIG_FALLTHROUGH __attribute__((fallthrough))
#else
#define ZIG_FALLTHROUGH
#endif

#endif
