/* <stdarg.h> for the Aro C compiler */

#pragma once
/* Todo: Set to 202311L once header is compliant with C23 */
#define __STDC_VERSION_STDARG_H__ 0

typedef __builtin_va_list va_list;
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202000L
/* C23 no longer requires the second parameter */
#define va_start(ap, ...) __builtin_va_start(ap, __VA_ARGS__)
#else
#define va_start(ap, param) __builtin_va_start(ap, param)
#endif
#define va_end(ap) __builtin_va_end(ap)
#define va_arg(ap, type) __builtin_va_arg(ap, type)

/* GCC and Clang always define __va_copy */
#define __va_copy(d, s) __builtin_va_copy(d, s)

/* but va_copy only on c99+ or when strict ansi mode is turned off */
#if __STDC_VERSION__ >= 199901L || !defined(__STRICT_ANSI__)
#define va_copy(d, s) __builtin_va_copy(d, s)
#endif

#ifndef __GNUC_VA_LIST
#define __GNUC_VA_LIST 1
typedef __builtin_va_list __gnuc_va_list;
#endif
