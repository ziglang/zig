/*	$NetBSD: int_types.h,v 1.7 2014/07/25 21:43:13 joerg Exp $	*/

/*-
 * Copyright (c) 1990 The Regents of the University of California.
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
 *	from: @(#)types.h	7.5 (Berkeley) 3/9/91
 */

#ifndef	_AMD64_INT_TYPES_H_
#define	_AMD64_INT_TYPES_H_

#ifdef __UINTPTR_TYPE__
#include <sys/common_int_types.h>
#else

#ifdef __x86_64__

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
typedef	long int		__int64_t;
typedef	unsigned long int	__uint64_t;

#define	__BIT_TYPES_DEFINED__

/* 7.18.1.4 Integer types capable of holding object pointers */

typedef	long		       __intptr_t;
typedef	unsigned long	      __uintptr_t;

#else	/*	__x86_64__	*/

#include <i386/int_types.h>

#endif	/*	__x86_64__	*/

#endif

#endif	/* !_AMD64_INT_TYPES_H_ */