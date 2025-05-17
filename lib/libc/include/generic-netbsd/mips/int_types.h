/*	$NetBSD: int_types.h,v 1.12 2014/08/13 22:56:56 matt Exp $	*/

/*-
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	from: @(#)types.h	8.3 (Berkeley) 1/5/94
 */

#ifndef	_MIPS_INT_TYPES_H_
#define	_MIPS_INT_TYPES_H_

#ifdef __UINTPTR_TYPE__
#include <sys/common_int_types.h>
#else
#include <sys/cdefs.h>

/*
 * 7.18.1 Integer types
 */

/* 7.18.1.1 Exact-width integer types */

typedef	signed char		 __int8_t;
typedef	unsigned char		__uint8_t;
typedef	short int		__int16_t;
typedef	unsigned short int     __uint16_t;
typedef	int			__int32_t;
typedef	unsigned int	       __uint32_t;
#ifdef __COMPILER_INT64__
typedef	__COMPILER_INT64__	__int64_t;
typedef	__COMPILER_UINT64__    __uint64_t;
#elif defined(_LP64)
typedef long int		__int64_t;
typedef unsigned long int      __uint64_t;
#else
/* LONGLONG */
typedef	long long int		__int64_t;
/* LONGLONG */
typedef	unsigned long long int __uint64_t;
#endif

#define	__BIT_TYPES_DEFINED__

/* 7.18.1.4 Integer types capable of holding object pointers */

#ifndef __mips_o32
typedef long int	       __intptr_t;
typedef unsigned long int     __uintptr_t;
#else
typedef	int		       __intptr_t;
typedef	unsigned int	      __uintptr_t;
#endif

#endif /* !__UINTPTR_TYPE__ */

#endif	/* !_MIPS_INT_TYPES_H_ */