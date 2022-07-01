/*
 * Copyright (c) 2000-2007 Apple Inc. All rights reserved.
 */
#ifndef _BSD_ARM__TYPES_H_
#define _BSD_ARM__TYPES_H_

/*
 * This header file contains integer types.  It's intended to also contain
 * flotaing point and other arithmetic types, as needed, later.
 */

#ifdef __GNUC__
typedef __signed char           __int8_t;
#else   /* !__GNUC__ */
typedef char                    __int8_t;
#endif  /* !__GNUC__ */
typedef unsigned char           __uint8_t;
typedef short                   __int16_t;
typedef unsigned short          __uint16_t;
typedef int                     __int32_t;
typedef unsigned int            __uint32_t;
typedef long long               __int64_t;
typedef unsigned long long      __uint64_t;

typedef long                    __darwin_intptr_t;
typedef unsigned int            __darwin_natural_t;

/*
 * The rune type below is declared to be an ``int'' instead of the more natural
 * ``unsigned long'' or ``long''.  Two things are happening here.  It is not
 * unsigned so that EOF (-1) can be naturally assigned to it and used.  Also,
 * it looks like 10646 will be a 31 bit standard.  This means that if your
 * ints cannot hold 32 bits, you will be in trouble.  The reason an int was
 * chosen over a long is that the is*() and to*() routines take ints (says
 * ANSI C), but they use __darwin_ct_rune_t instead of int.  By changing it
 * here, you lose a bit of ANSI conformance, but your programs will still
 * work.
 *
 * NOTE: rune_t is not covered by ANSI nor other standards, and should not
 * be instantiated outside of lib/libc/locale.  Use wchar_t.  wchar_t and
 * rune_t must be the same type.  Also wint_t must be no narrower than
 * wchar_t, and should also be able to hold all members of the largest
 * character set plus one extra value (WEOF). wint_t must be at least 16 bits.
 */

typedef int                     __darwin_ct_rune_t;     /* ct_rune_t */

/*
 * mbstate_t is an opaque object to keep conversion state, during multibyte
 * stream conversions.  The content must not be referenced by user programs.
 */
typedef union {
	char            __mbstate8[128];
	long long       _mbstateL;                      /* for alignment */
} __mbstate_t;

typedef __mbstate_t             __darwin_mbstate_t;     /* mbstate_t */

#if defined(__PTRDIFF_TYPE__)
typedef __PTRDIFF_TYPE__        __darwin_ptrdiff_t;     /* ptr1 - ptr2 */
#elif defined(__LP64__)
typedef long                    __darwin_ptrdiff_t;     /* ptr1 - ptr2 */
#else
typedef int                     __darwin_ptrdiff_t;     /* ptr1 - ptr2 */
#endif /* __GNUC__ */

#if defined(__SIZE_TYPE__)
typedef __SIZE_TYPE__           __darwin_size_t;        /* sizeof() */
#else
typedef unsigned long           __darwin_size_t;        /* sizeof() */
#endif

#if (__GNUC__ > 2)
typedef __builtin_va_list       __darwin_va_list;       /* va_list */
#else
typedef void *                  __darwin_va_list;       /* va_list */
#endif

#if defined(__WCHAR_TYPE__)
typedef __WCHAR_TYPE__          __darwin_wchar_t;       /* wchar_t */
#else
typedef __darwin_ct_rune_t      __darwin_wchar_t;       /* wchar_t */
#endif

typedef __darwin_wchar_t        __darwin_rune_t;        /* rune_t */

#if defined(__WINT_TYPE__)
typedef __WINT_TYPE__           __darwin_wint_t;        /* wint_t */
#else
typedef __darwin_ct_rune_t      __darwin_wint_t;        /* wint_t */
#endif

typedef unsigned long           __darwin_clock_t;       /* clock() */
typedef __uint32_t              __darwin_socklen_t;     /* socklen_t (duh) */
typedef long                    __darwin_ssize_t;       /* byte count or error */
typedef long                    __darwin_time_t;        /* time() */

#endif  /* _BSD_ARM__TYPES_H_ */