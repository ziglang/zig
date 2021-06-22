// Copyright (c) 2015-2017 Nuxi, https://nuxi.nl/
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.

#ifndef ___CDEFS_H_
#define ___CDEFS_H_

// Version information.
#define __cloudlibc__ 1
#define __cloudlibc_major__ 0
#define __cloudlibc_minor__ 102

#ifdef __cplusplus
#define __BEGIN_DECLS extern "C" {
#define __END_DECLS }
#else
#define __BEGIN_DECLS
#define __END_DECLS
#endif

// Whether we should provide inline versions of functions. Due to C++'s
// support for namespaces, it is generally a bad idea to declare
// function macros.
#ifdef __cplusplus
#define _CLOUDLIBC_INLINE_FUNCTIONS 0
#else
#define _CLOUDLIBC_INLINE_FUNCTIONS 1
#endif

// Compiler-independent annotations.

#ifndef __has_builtin
#define __has_builtin(x) 0
#endif
#ifndef __has_extension
#define __has_extension(x) __has_feature(x)
#endif
#ifndef __has_feature
#define __has_feature(x) 0
#endif

#define __offsetof(type, member) __builtin_offsetof(type, member)
#define __containerof(ptr, type, member) \
  ((type *)((char *)(ptr)-__offsetof(type, member)))

#define __extname(x) __asm__(x)
#define __malloc_like __attribute__((__malloc__))
#define __pure2 __attribute__((__const__))
#define __pure __attribute__((__pure__))
#define __section(x) __attribute__((__section__(x)))
#define __unused __attribute__((__unused__))
#define __used __attribute__((__used__))
#define __weak_symbol __attribute__((__weak__))

// Format string argument type checking.
#define __printflike(format, va) \
  __attribute__((__format__(__printf__, format, va)))
#define __scanflike(format, va) \
  __attribute__((__format__(__scanf__, format, va)))
// TODO(ed): Enable this once supported by LLVM:
// https://llvm.org/bugs/show_bug.cgi?id=16810
#define __wprintflike(format, va)
#define __wscanflike(format, va)

#define __strong_reference(oldsym, newsym) \
  extern __typeof__(oldsym) newsym __attribute__((__alias__(#oldsym)))

// Convenience macros.

#define __arraycount(x) (sizeof(x) / sizeof((x)[0]))
#define __howmany(x, y) (((x) + (y)-1) / (y))
#define __rounddown(x, y) (((x) / (y)) * (y))
#define __roundup(x, y) ((((x) + (y)-1) / (y)) * (y))

// Lock annotations.

#if __has_extension(c_thread_safety_attributes)
#define __lock_annotate(x) __attribute__((x))
#else
#define __lock_annotate(x)
#endif

#define __lockable __lock_annotate(lockable)

#define __locks_exclusive(...) \
  __lock_annotate(exclusive_lock_function(__VA_ARGS__))
#define __locks_shared(...) __lock_annotate(shared_lock_function(__VA_ARGS__))

#define __trylocks_exclusive(...) \
  __lock_annotate(exclusive_trylock_function(__VA_ARGS__))
#define __trylocks_shared(...) \
  __lock_annotate(shared_trylock_function(__VA_ARGS__))

#define __unlocks(...) __lock_annotate(unlock_function(__VA_ARGS__))

#define __asserts_exclusive(...) \
  __lock_annotate(assert_exclusive_lock(__VA_ARGS__))
#define __asserts_shared(...) __lock_annotate(assert_shared_lock(__VA_ARGS__))

#define __requires_exclusive(...) \
  __lock_annotate(exclusive_locks_required(__VA_ARGS__))
#define __requires_shared(...) \
  __lock_annotate(shared_locks_required(__VA_ARGS__))
#define __requires_unlocked(...) __lock_annotate(locks_excluded(__VA_ARGS__))

#define __no_lock_analysis __lock_annotate(no_thread_safety_analysis)

#define __guarded_by(x) __lock_annotate(guarded_by(x))
#define __pt_guarded_by(x) __lock_annotate(pt_guarded_by(x))

// Const preservation.
//
// Functions like strchr() allow you to silently discard a const
// qualifier from a string. This macro can be used to wrap such
// functions to propagate the const keyword where possible.
//
// This macro has many limitations, such as only being able to detect
// constness for void, char and wchar_t. For Clang, it also doesn't seem
// to work on string literals.

#define __preserve_const(type, name, arg, ...) \
  _Generic(arg,                                                    \
           const void *: (const type *)name(__VA_ARGS__),          \
           const char *: (const type *)name(__VA_ARGS__),          \
           const signed char *: (const type *)name(__VA_ARGS__),   \
           const unsigned char *: (const type *)name(__VA_ARGS__), \
           const __wchar_t *: (const type *)name(__VA_ARGS__),     \
           default: name(__VA_ARGS__))

#endif
