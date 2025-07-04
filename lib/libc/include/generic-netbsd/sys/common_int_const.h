/*	$NetBSD: common_int_const.h,v 1.2 2022/05/26 09:55:31 rillig Exp $	*/

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Joerg Sonnenberger.
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

#ifndef _SYS_COMMON_INT_CONST_H_
#define _SYS_COMMON_INT_CONST_H_

#ifndef __INTMAX_C_SUFFIX__
#error Your compiler does not provide integer constant suffix macros.
#endif

#define __int_join_(c,suffix) c ## suffix
#define __int_join(c,suffix) __int_join_(c,suffix)
/*
 * 7.18.4 Macros for integer constants
 */

/* 7.18.4.1 Macros for minimum-width integer constants */

#define	INT8_C(c)	__int_join(c, __INT8_C_SUFFIX__)
#define	INT16_C(c)	__int_join(c, __INT16_C_SUFFIX__)
#define	INT32_C(c)	__int_join(c, __INT32_C_SUFFIX__)
#define	INT64_C(c)	__int_join(c, __INT64_C_SUFFIX__)

#define	UINT8_C(c)	__int_join(c, __UINT8_C_SUFFIX__)
#define	UINT16_C(c)	__int_join(c, __UINT16_C_SUFFIX__)
#define	UINT32_C(c)	__int_join(c, __UINT32_C_SUFFIX__)
#define	UINT64_C(c)	__int_join(c, __UINT64_C_SUFFIX__)

/* 7.18.4.2 Macros for greatest-width integer constants */

#define	INTMAX_C(c)	__int_join(c, __INTMAX_C_SUFFIX__)
#define	UINTMAX_C(c)	__int_join(c, __UINTMAX_C_SUFFIX__)

#endif /* _SYS_COMMON_INT_CONST_H_ */