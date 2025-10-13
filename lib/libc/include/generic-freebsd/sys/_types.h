/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2002 Mike Barcroft <mike@FreeBSD.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS__TYPES_H_
#define _SYS__TYPES_H_

#include <sys/cdefs.h>

/*
 * Basic types upon which most other types are built.
 *
 * Note: It would be nice to simply use the compiler-provided __FOO_TYPE__
 * macros. However, in order to do so we have to check that those match the
 * previous typedefs exactly (not just that they have the same size) since any
 * change would be an ABI break. For example, changing `long` to `long long`
 * results in different C++ name mangling.
 */
typedef	signed char		__int8_t;
typedef	unsigned char		__uint8_t;
typedef	short			__int16_t;
typedef	unsigned short		__uint16_t;
typedef	int			__int32_t;
typedef	unsigned int		__uint32_t;
#if __SIZEOF_LONG__ == 8
typedef	long			__int64_t;
typedef	unsigned long		__uint64_t;
#elif __SIZEOF_LONG__ == 4
__extension__
typedef	long long		__int64_t;
__extension__
typedef	unsigned long long	__uint64_t;
#else
#error unsupported long size
#endif

typedef	__int8_t	__int_least8_t;
typedef	__int16_t	__int_least16_t;
typedef	__int32_t	__int_least32_t;
typedef	__int64_t	__int_least64_t;
typedef	__int64_t	__intmax_t;
typedef	__uint8_t	__uint_least8_t;
typedef	__uint16_t	__uint_least16_t;
typedef	__uint32_t	__uint_least32_t;
typedef	__uint64_t	__uint_least64_t;
typedef	__uint64_t	__uintmax_t;

#if __SIZEOF_POINTER__ == 8
typedef	__int64_t	__intptr_t;
typedef	__int64_t	__intfptr_t;
typedef	__uint64_t	__uintptr_t;
typedef	__uint64_t	__uintfptr_t;
typedef	__uint64_t	__vm_offset_t;
typedef	__uint64_t	__vm_size_t;
#elif __SIZEOF_POINTER__ == 4
typedef	__int32_t	__intptr_t;
typedef	__int32_t	__intfptr_t;
typedef	__uint32_t	__uintptr_t;
typedef	__uint32_t	__uintfptr_t;
typedef	__uint32_t	__vm_offset_t;
typedef	__uint32_t	__vm_size_t;
#else
#error unsupported pointer size
#endif

#if __SIZEOF_SIZE_T__ == 8
typedef	__uint64_t	__size_t;	/* sizeof() */
typedef	__int64_t	__ssize_t;	/* byte count or error */
#elif __SIZEOF_SIZE_T__ == 4
typedef	__uint32_t	__size_t;	/* sizeof() */
typedef	__int32_t	__ssize_t;	/* byte count or error */
#else
#error unsupported size_t size
#endif

#if __SIZEOF_PTRDIFF_T__ == 8
typedef	__int64_t	__ptrdiff_t;	/* ptr1 - ptr2 */
#elif __SIZEOF_PTRDIFF_T__ == 4
typedef	__int32_t	__ptrdiff_t;	/* ptr1 - ptr2 */
#else
#error unsupported ptrdiff_t size
#endif

/*
 * Target-dependent type definitions.
 */
#include <machine/_types.h>

/*
 * Standard type definitions.
 */
typedef	__int32_t	__blksize_t;	/* file block size */
typedef	__int64_t	__blkcnt_t;	/* file block count */
typedef	__int32_t	__clockid_t;	/* clock_gettime()... */
typedef	__uint32_t	__fflags_t;	/* file flags */
typedef	__uint64_t	__fsblkcnt_t;
typedef	__uint64_t	__fsfilcnt_t;
typedef	__uint32_t	__gid_t;
typedef	__int64_t	__id_t;		/* can hold a gid_t, pid_t, or uid_t */
typedef	__uint64_t	__ino_t;	/* inode number */
typedef	long		__key_t;	/* IPC key (for Sys V IPC) */
typedef	__int32_t	__lwpid_t;	/* Thread ID (a.k.a. LWP) */
typedef	__uint16_t	__mode_t;	/* permissions */
typedef	int		__accmode_t;	/* access permissions */
typedef	int		__nl_item;
typedef	__uint64_t	__nlink_t;	/* link count */
typedef	__int64_t	__off_t;	/* file offset */
typedef	__int64_t	__off64_t;	/* file offset (alias) */
typedef	__int32_t	__pid_t;	/* process [group] */
typedef	__int64_t	__sbintime_t;
typedef	__int64_t	__rlim_t;	/* resource limit - intentionally */
					/* signed, because of legacy code */
					/* that uses -1 for RLIM_INFINITY */
typedef	__uint8_t	__sa_family_t;
typedef	__uint32_t	__socklen_t;
typedef	long		__suseconds_t;	/* microseconds (signed) */
typedef	struct __timer	*__timer_t;	/* timer_gettime()... */
typedef	struct __mq	*__mqd_t;	/* mq_open()... */
typedef	__uint32_t	__uid_t;
typedef	unsigned int	__useconds_t;	/* microseconds (unsigned) */
typedef	int		__cpuwhich_t;	/* which parameter for cpuset. */
typedef	int		__cpulevel_t;	/* level parameter for cpuset. */
typedef int		__cpusetid_t;	/* cpuset identifier. */
typedef __int64_t	__daddr_t;	/* bwrite(3), FIOBMAP2, etc */

/*
 * Unusual type definitions.
 */
/*
 * rune_t is declared to be an ``int'' instead of the more natural
 * ``unsigned long'' or ``long''.  Two things are happening here.  It is not
 * unsigned so that EOF (-1) can be naturally assigned to it and used.  Also,
 * it looks like 10646 will be a 31 bit standard.  This means that if your
 * ints cannot hold 32 bits, you will be in trouble.  The reason an int was
 * chosen over a long is that the is*() and to*() routines take ints (says
 * ANSI C), but they use __ct_rune_t instead of int.
 *
 * NOTE: rune_t is not covered by ANSI nor other standards, and should not
 * be instantiated outside of lib/libc/locale.  Use wchar_t.  wint_t and
 * rune_t must be the same type.  Also, wint_t should be able to hold all
 * members of the largest character set plus one extra value (WEOF), and
 * must be at least 16 bits.
 */
typedef	int		__ct_rune_t;	/* arg type for ctype funcs */
typedef	__ct_rune_t	__rune_t;	/* rune_t (see above) */
typedef	__ct_rune_t	__wint_t;	/* wint_t (see above) */

/* Clang already provides these types as built-ins, but only in C++ mode. */
#if !defined(__clang__) || !defined(__cplusplus)
typedef	__uint_least16_t __char16_t;
typedef	__uint_least32_t __char32_t;
#endif
/* In C++11, char16_t and char32_t are built-in types. */
#if defined(__cplusplus) && __cplusplus >= 201103L
#define	_CHAR16_T_DECLARED
#define	_CHAR32_T_DECLARED
#endif

typedef struct {
	long long __max_align1 __aligned(_Alignof(long long));
#ifndef _STANDALONE
	long double __max_align2 __aligned(_Alignof(long double));
#endif
} __max_align_t;

typedef	__uint64_t	__dev_t;	/* device number */

typedef	__uint32_t	__fixpt_t;	/* fixed point number */

/*
 * mbstate_t is an opaque object to keep conversion state during multibyte
 * stream conversions.
 */
typedef union {
	char		__mbstate8[128];
	__int64_t	_mbstateL;	/* for alignment */
} __mbstate_t;

typedef __uintmax_t     __rman_res_t;

/*
 * Types for varargs. These are all provided by builtin types these
 * days, so centralize their definition.
 */
typedef	__builtin_va_list	__va_list;	/* internally known to gcc */
#if !defined(__GNUC_VA_LIST) && !defined(__NO_GNUC_VA_LIST)
#define __GNUC_VA_LIST
typedef __va_list		__gnuc_va_list;	/* compatibility w/GNU headers*/
#endif

/*
 * When the following macro is defined, the system uses 64-bit inode numbers.
 * Programs can use this to avoid including <sys/param.h>, with its associated
 * namespace pollution.
 */
#define	__INO64

#endif /* !_SYS__TYPES_H_ */