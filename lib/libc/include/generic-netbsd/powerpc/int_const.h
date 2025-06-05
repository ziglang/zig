/*	$NetBSD: int_const.h,v 1.5 2014/08/13 22:51:59 matt Exp $	*/

/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus Klein.
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

#ifndef _POWERPC_INT_CONST_H_
#define _POWERPC_INT_CONST_H_

#ifdef __INTMAX_C_SUFFIX__
#include <sys/common_int_const.h>
#else
/*
 * 7.18.4 Macros for integer constants
 */

/* 7.18.4.1 Macros for minimum-width integer constants */

#define	INT8_C(c)	c
#define	INT16_C(c)	c
#define	INT32_C(c)	c
#ifdef _LP64
#define	INT64_C(c)	c ## L
#else
#define	INT64_C(c)	c ## LL
#endif

#define	UINT8_C(c)	c
#define	UINT16_C(c)	c
#define	UINT32_C(c)	c ## U
#ifdef _LP64
#define	UINT64_C(c)	c ## UL
#else
#define	UINT64_C(c)	c ## ULL
#endif

/* 7.18.4.2 Macros for greatest-width integer constants */

#ifdef _LP64
#define	INTMAX_C(c)	c ## L
#define	UINTMAX_C(c)	c ## UL
#else
#define	INTMAX_C(c)	c ## LL
#define	UINTMAX_C(c)	c ## ULL
#endif

#endif /* !__INTMAX_C_SUFFIX__ */

#endif /* !_POWERPC_INT_CONST_H_ */