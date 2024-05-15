/*===---- stdarg.h - Variable argument handling ----------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

/*
 * This header is designed to be included multiple times. If any of the __need_
 * macros are defined, then only that subset of interfaces are provided. This
 * can be useful for POSIX headers that need to not expose all of stdarg.h, but
 * need to use some of its interfaces. Otherwise this header provides all of
 * the expected interfaces.
 *
 * When clang modules are enabled, this header is a textual header. It ignores
 * its header guard so that multiple submodules can export its interfaces.
 * Take module SM with submodules A and B, whose headers both include stdarg.h
 * When SM.A builds, __STDARG_H will be defined. When SM.B builds, the
 * definition from SM.A will leak when building without local submodule
 * visibility. stdarg.h wouldn't include any of its implementation headers, and
 * SM.B wouldn't import any of the stdarg modules, and SM.B's `export *`
 * wouldn't export any stdarg interfaces as expected. However, since stdarg.h
 * ignores its header guard when building with modules, it all works as
 * expected.
 *
 * When clang modules are not enabled, the header guards can function in the
 * normal simple fashion.
 */
#if !defined(__STDARG_H) || __has_feature(modules) ||                          \
    defined(__need___va_list) || defined(__need_va_list) ||                    \
    defined(__need_va_arg) || defined(__need___va_copy) ||                     \
    defined(__need_va_copy)

#if !defined(__need___va_list) && !defined(__need_va_list) &&                  \
    !defined(__need_va_arg) && !defined(__need___va_copy) &&                   \
    !defined(__need_va_copy)
#define __STDARG_H
#define __need___va_list
#define __need_va_list
#define __need_va_arg
#define __need___va_copy
/* GCC always defines __va_copy, but does not define va_copy unless in c99 mode
 * or -ansi is not specified, since it was not part of C90.
 */
#if (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L) ||              \
    (defined(__cplusplus) && __cplusplus >= 201103L) ||                        \
    !defined(__STRICT_ANSI__)
#define __need_va_copy
#endif
#endif

#ifdef __need___va_list
#include <__stdarg___gnuc_va_list.h>
#undef __need___va_list
#endif /* defined(__need___va_list) */

#ifdef __need_va_list
#include <__stdarg_va_list.h>
#undef __need_va_list
#endif /* defined(__need_va_list) */

#ifdef __need_va_arg
#include <__stdarg_va_arg.h>
#undef __need_va_arg
#endif /* defined(__need_va_arg) */

#ifdef __need___va_copy
#include <__stdarg___va_copy.h>
#undef __need___va_copy
#endif /* defined(__need___va_copy) */

#ifdef __need_va_copy
#include <__stdarg_va_copy.h>
#undef __need_va_copy
#endif /* defined(__need_va_copy) */

#endif
