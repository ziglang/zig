#ifdef __wasilibc_unmodified_upstream /* Use the compiler's stddef.h */
#ifndef _STDDEF_H
#define _STDDEF_H

#ifdef __cplusplus
#define NULL 0L
#else
#define NULL ((void*)0)
#endif

#define __NEED_ptrdiff_t
#define __NEED_size_t
#define __NEED_wchar_t
#if __STDC_VERSION__ >= 201112L || __cplusplus >= 201103L
#define __NEED_max_align_t
#endif

#include <bits/alltypes.h>

#if __GNUC__ > 3
#define offsetof(type, member) __builtin_offsetof(type, member)
#else
#define offsetof(type, member) ((size_t)( (char *)&(((type *)0)->member) - (char *)0 ))
#endif

#endif
#else

/* Just use the compiler's stddef.h. */
#include_next <stddef.h>

/* Define musl's include guard, in case any code depends on that. */
#if defined(__STDDEF_H) && !defined(_STDDEF_H)
#define _STDDEF_H
#endif

#endif
