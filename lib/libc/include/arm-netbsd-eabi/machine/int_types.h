/*	$NetBSD: int_types.h,v 1.17 2014/07/25 21:43:13 joerg Exp $	*/

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _ARM_INT_TYPES_H_
#define _ARM_INT_TYPES_H_

#ifdef __UINTPTR_TYPE__
#include <sys/common_int_types.h>
#else
#include <sys/cdefs.h>

/*
 * 7.18.1 Integer types
 */

/* 7.18.1.1 Exact-width integer types */

#ifndef __UINT8_TYPE__
# define __UINT8_TYPE__		unsigned char
#endif
#ifndef __INT8_TYPE__
# define __INT8_TYPE__		signed char
#endif
#ifndef __UINT16_TYPE__
# ifndef __INT16_TYPE__
#  define __INT16_TYPE__	short int
# endif
# define __UINT16_TYPE__	unsigned __INT16_TYPE__
#endif
#ifndef __UINT32_TYPE__
# ifndef __INT32_TYPE__
#  define __INT32_TYPE__	int
# endif
# define __UINT32_TYPE__	unsigned __INT32_TYPE__
#endif
#ifndef __UINT64_TYPE__
# ifndef __INT64_TYPE__
#  define __INT64_TYPE__	long long int
# endif
# define __UINT64_TYPE__	unsigned __INT64_TYPE__
#endif

#ifdef __clang__
typedef	signed __INT8_TYPE__	   __int8_t;
#else
typedef	__INT8_TYPE__		   __int8_t;
#endif
typedef	__UINT8_TYPE__		  __uint8_t;
typedef	__INT16_TYPE__		  __int16_t;
typedef	__UINT16_TYPE__		 __uint16_t;
typedef	__INT32_TYPE__		  __int32_t;
typedef	__UINT32_TYPE__		 __uint32_t;
typedef	__INT64_TYPE__		  __int64_t;
typedef	__UINT64_TYPE__		 __uint64_t;

#define	__BIT_TYPES_DEFINED__

/* 7.18.1.4 Integer types capable of holding object pointers */

#ifndef __UINTPTR_TYPE__
# ifndef __INTPTR_TYPE__
#  define __INTPTR_TYPE__	long int
# endif
# define __UINTPTR_TYPE__	unsigned __INTPTR_TYPE__
#endif

typedef	__INTPTR_TYPE__		 __intptr_t;
typedef	__UINTPTR_TYPE__	__uintptr_t;
#endif

#endif	/* !_ARM_INT_TYPES_H_ */