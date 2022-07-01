/*
 * Copyright (c) 2000-2003 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
#ifndef _BSD_I386__TYPES_H_
#define _BSD_I386__TYPES_H_

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

#endif  /* _BSD_I386__TYPES_H_ */