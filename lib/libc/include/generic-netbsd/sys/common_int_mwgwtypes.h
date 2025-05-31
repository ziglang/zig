/*	$NetBSD: common_int_mwgwtypes.h,v 1.1 2014/07/25 21:43:13 joerg Exp $	*/

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

#ifndef _SYS_COMMON_INT_MWGWTYPES_H_
#define _SYS_COMMON_INT_MWGWTYPES_H_

#ifndef __UINT_FAST64_TYPE__
#error Your compiler does not provide min/fast width type macros.
#endif

/*
 * 7.18.1 Integer types
 */

/* 7.18.1.2 Minimum-width integer types */

typedef	__INT_LEAST8_TYPE__		  int_least8_t;
typedef	__UINT_LEAST8_TYPE__		 uint_least8_t;
typedef	__INT_LEAST16_TYPE__		 int_least16_t;
typedef	__UINT_LEAST16_TYPE__		uint_least16_t;
typedef	__INT_LEAST32_TYPE__		 int_least32_t;
typedef	__UINT_LEAST32_TYPE__		uint_least32_t;
typedef	__INT_LEAST64_TYPE__		 int_least64_t;
typedef	__UINT_LEAST64_TYPE__		uint_least64_t;

/* 7.18.1.3 Fastest minimum-width integer types */
typedef	__INT_FAST8_TYPE__		   int_fast8_t;
typedef	__UINT_FAST8_TYPE__		  uint_fast8_t;
typedef	__INT_FAST16_TYPE__		  int_fast16_t;
typedef	__UINT_FAST16_TYPE__		 uint_fast16_t;
typedef	__INT_FAST32_TYPE__		  int_fast32_t;
typedef	__UINT_FAST32_TYPE__		 uint_fast32_t;
typedef	__INT_FAST64_TYPE__		  int_fast64_t;
typedef	__UINT_FAST64_TYPE__		 uint_fast64_t;

/* 7.18.1.5 Greatest-width integer types */

typedef	__INTMAX_TYPE__			      intmax_t;
typedef	__UINTMAX_TYPE__		     uintmax_t;

#endif /* _SYS_COMMON_INT_MWGWTYPES_H_ */