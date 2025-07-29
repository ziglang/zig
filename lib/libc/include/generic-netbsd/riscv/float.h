/* $NetBSD: float.h,v 1.1 2014/09/19 17:36:26 matt Exp $ */

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

#ifndef _RISCV_FLOAT_H_
#define _RISCV_FLOAT_H_

#include <sys/cdefs.h>

#define LDBL_MANT_DIG	__LDBL_MANT_DIG__
#define LDBL_DIG	__LDBL_DIG__
#define LDBL_MIN_EXP	__LDBL_MIN_EXP__
#define LDBL_MIN_10_EXP	__LDBL_MIN_10_EXP__
#define LDBL_MAX_EXP	__LDBL_MAX_EXP__
#define LDBL_MAX_10_EXP	__LDBL_MAX_10_EXP__
#define LDBL_EPSILON	__LDBL_EPSILON__
#define LDBL_MIN	__LDBL_MIN__
#define LDBL_MAX	__LDBL_MAX__

#include <sys/float_ieee754.h>

#if (!defined(_ANSI_SOURCE) && !defined(_POSIX_C_SOURCE) \
	 && !defined(_XOPEN_SOURCE)) \
	|| (__STDC_VERSION__ - 0) >= 199901L \
	|| (_POSIX_C_SOURCE - 0) >= 200112L \
	|| ((_XOPEN_SOURCE  - 0) >= 600) \
	|| defined(_ISOC99_SOURCE) || defined(_NETBSD_SOURCE)
#define DECIMAL_DIG	__DECIMAL_DIG__
#endif

#endif /* !_RISCV_FLOAT_H_ */