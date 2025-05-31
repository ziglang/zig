/*	$NetBSD: float.h,v 1.18 2020/07/26 08:08:41 simonb Exp $ */

/*-
 * Copyright (c) 2013 The NetBSD Foundation, Inc.
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
#ifndef _MIPS_FLOAT_H_
#define	_MIPS_FLOAT_H_

#include <sys/cdefs.h>

#if defined(__mips_n32) || defined(__mips_n64)

#if __GNUC_PREREQ__(4,1)

#define	LDBL_MANT_DIG	__LDBL_MANT_DIG__
#define	LDBL_DIG	__LDBL_DIG__
#define	LDBL_MIN_EXP	__LDBL_MIN_EXP__
#define	LDBL_MIN_10_EXP	__LDBL_MIN_10_EXP__
#define	LDBL_MAX_EXP	__LDBL_MAX_EXP__
#define	LDBL_MAX_10_EXP	__LDBL_MAX_10_EXP__
#define	LDBL_EPSILON	__LDBL_EPSILON__
#define	LDBL_MIN	__LDBL_MIN__
#define	LDBL_MAX	__LDBL_MAX__

#else

#define	LDBL_MANT_DIG	113
#define	LDBL_DIG	33
#define	LDBL_MIN_EXP	(-16381)
#define	LDBL_MIN_10_EXP	(-4931)
#define	LDBL_MAX_EXP	16384
#define	LDBL_MAX_10_EXP	4932
#if __STDC_VERSION__ >= 199901L
#define	LDBL_EPSILON	0x1p-112L
#define	LDBL_MIN	0x1p-16382L
#define	LDBL_MAX	0x1.ffffffffffffffffffffffffffffp+16383L,
#else
#define	LDBL_EPSILON	1.9259299443872358530559779425849273E-34L
#define	LDBL_MIN	3.3621031431120935062626778173217526E-4932L
#define	LDBL_MAX	1.1897314953572317650857593266280070E+4932L
#endif

#endif /* !__GNUC_PREREQ__(4,1) */

#endif	/* __mips_n32 || __mips_n64 */

#include <sys/float_ieee754.h>

#if defined(__mips_n32) || defined(__mips_n64)

#if !defined(_ANSI_SOURCE) && !defined(_POSIX_C_SOURCE) && \
    !defined(_XOPEN_SOURCE) || \
    ((__STDC_VERSION__ - 0) >= 199901L) || \
    ((_POSIX_C_SOURCE - 0) >= 200112L) || \
    ((_XOPEN_SOURCE  - 0) >= 600) || \
    defined(_ISOC99_SOURCE) || defined(_NETBSD_SOURCE)
#if __GNUC_PREREQ__(4,1)
#define	DECIMAL_DIG	__DECIMAL_DIG__
#else
#define	DECIMAL_DIG	36
#endif
#endif /* !defined(_ANSI_SOURCE) && ... */

#endif	/* __mips_n32 || __mips_n64 */

#endif	/* _MIPS_FLOAT_H_ */