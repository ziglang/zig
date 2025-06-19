/*	$NetBSD: stdint.h,v 1.8 2018/11/06 16:26:44 maya Exp $	*/

/*-
 * Copyright (c) 2001, 2004 The NetBSD Foundation, Inc.
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

#ifndef _SYS_STDINT_H_
#define _SYS_STDINT_H_

#include <sys/cdefs.h>
#include <machine/int_types.h>

#ifndef	_BSD_INT8_T_
typedef	__int8_t	int8_t;
#define	_BSD_INT8_T_
#endif

#ifndef	_BSD_UINT8_T_
typedef	__uint8_t	uint8_t;
#define	_BSD_UINT8_T_
#endif

#ifndef	_BSD_INT16_T_
typedef	__int16_t	int16_t;
#define	_BSD_INT16_T_
#endif

#ifndef	_BSD_UINT16_T_
typedef	__uint16_t	uint16_t;
#define	_BSD_UINT16_T_
#endif

#ifndef	_BSD_INT32_T_
typedef	__int32_t	int32_t;
#define	_BSD_INT32_T_
#endif

#ifndef	_BSD_UINT32_T_
typedef	__uint32_t	uint32_t;
#define	_BSD_UINT32_T_
#endif

#ifndef	_BSD_INT64_T_
typedef	__int64_t	int64_t;
#define	_BSD_INT64_T_
#endif

#ifndef	_BSD_UINT64_T_
typedef	__uint64_t	uint64_t;
#define	_BSD_UINT64_T_
#endif

#ifndef	_BSD_INTPTR_T_
typedef	__intptr_t	intptr_t;
#define	_BSD_INTPTR_T_
#endif

#ifndef	_BSD_UINTPTR_T_
typedef	__uintptr_t	uintptr_t;
#define	_BSD_UINTPTR_T_
#endif

#include <machine/int_mwgwtypes.h>

#if !defined(__cplusplus) || defined(__STDC_LIMIT_MACROS) || \
    (__cplusplus >= 201103L)
#include <machine/int_limits.h>
#endif

#if !defined(__cplusplus) || defined(__STDC_CONSTANT_MACROS) || \
    (__cplusplus >= 201103L)
#include <machine/int_const.h>
#endif

#include <machine/wchar_limits.h>

#endif /* !_SYS_STDINT_H_ */