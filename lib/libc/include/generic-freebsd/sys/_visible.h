/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Berkeley Software Design, Inc.
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
 */

#ifndef	_SYS__VISIBLE_H_
#define	_SYS__VISIBLE_H_

/*-
 * The following definitions are an extension of the behavior originally
 * implemented in <sys/_posix.h>, but with a different level of granularity.
 * POSIX.1 requires that the macros we test be defined before any standard
 * header file is included.
 *
 * Here's a quick run-down of the versions (and some informal names)
 *  defined(_POSIX_SOURCE)		1003.1-1988
 *					encoded as 198808 below
 *  _POSIX_C_SOURCE == 1		1003.1-1990
 *					encoded as 199009 below
 *  _POSIX_C_SOURCE == 2		1003.2-1992 C Language Binding Option
 *					encoded as 199209 below
 *  _POSIX_C_SOURCE == 199309		1003.1b-1993
 *					(1003.1 Issue 4, Single Unix Spec v1, Unix 93)
 *  _POSIX_C_SOURCE == 199506		1003.1c-1995, 1003.1i-1995,
 *					and the omnibus ISO/IEC 9945-1: 1996
 *					(1003.1 Issue 5, Single	Unix Spec v2, Unix 95)
 *  _POSIX_C_SOURCE == 200112		1003.1-2001 (1003.1 Issue 6, Unix 03)
 *					with _XOPEN_SOURCE=600
 *  _POSIX_C_SOURCE == 200809		1003.1-2008 (1003.1 Issue 7)
 *					IEEE Std 1003.1-2017 (Rev of 1003.1-2008) is
 *					1003.1-2008 with two TCs applied and
 *					_XOPEN_SOURCE=700
 * _POSIX_C_SOURCE == 202405		1003.1-2004 (1003.1 Issue 8), IEEE Std 1003.1-2024
 * 					with _XOPEN_SOURCE=800
 *
 * In addition, the X/Open Portability Guide, which is now the Single UNIX
 * Specification, defines a feature-test macro which indicates the version of
 * that specification, and which subsumes _POSIX_C_SOURCE.
 *
 * Our macros begin with two underscores to avoid namespace screwage.
 */

/* Deal with IEEE Std. 1003.1-1990, in which _POSIX_C_SOURCE == 1. */
#if defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE == 1
#undef _POSIX_C_SOURCE		/* Probably illegal, but beyond caring now. */
#define	_POSIX_C_SOURCE		199009
#endif

/* Deal with IEEE Std. 1003.2-1992, in which _POSIX_C_SOURCE == 2. */
#if defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE == 2
#undef _POSIX_C_SOURCE
#define	_POSIX_C_SOURCE		199209
#endif

/*
 * Deal with various X/Open Portability Guides and Single UNIX Spec. We use the
 * '- 0' construct so software that defines _XOPEN_SOURCE to nothing doesn't
 * cause errors. X/Open CAE Specification, August 1994, System Interfaces and
 * Headers, Issue 4, Version 2 section 2.2 states an empty definition means the
 * same thing as _POSIX_C_SOURCE == 2. This broadly mirrors "System V Interface
 * Definition, Fourth Edition", but earlier editions suggest some ambiguity.
 * However, FreeBSD has histoically implemented this as a NOP, so we just
 * document what it should be for now to not break ports gratuitously.
 */
#ifdef _XOPEN_SOURCE
#if _XOPEN_SOURCE - 0 >= 800
#define	__XSI_VISIBLE		800
#undef _POSIX_C_SOURCE
#define	_POSIX_C_SOURCE		202405
#elif _XOPEN_SOURCE - 0 >= 700
#define	__XSI_VISIBLE		700
#undef _POSIX_C_SOURCE
#define	_POSIX_C_SOURCE		200809
#elif _XOPEN_SOURCE - 0 >= 600
#define	__XSI_VISIBLE		600
#undef _POSIX_C_SOURCE
#define	_POSIX_C_SOURCE		200112
#elif _XOPEN_SOURCE - 0 >= 500
#define	__XSI_VISIBLE		500
#undef _POSIX_C_SOURCE
#define	_POSIX_C_SOURCE		199506
#else
/* #define	_POSIX_C_SOURCE		199209 */
#endif
#endif

/*
 * Deal with all versions of POSIX.  The ordering relative to the tests above is
 * important.
 */
#if defined(_POSIX_SOURCE) && !defined(_POSIX_C_SOURCE)
#define	_POSIX_C_SOURCE		198808
#endif
#ifdef _POSIX_C_SOURCE
#if _POSIX_C_SOURCE >= 202405
#define	__POSIX_VISIBLE		202405
#define	__ISO_C_VISIBLE		2017
#elif _POSIX_C_SOURCE >= 200809
#define	__POSIX_VISIBLE		200809
#define	__ISO_C_VISIBLE		1999
#elif _POSIX_C_SOURCE >= 200112
#define	__POSIX_VISIBLE		200112
#define	__ISO_C_VISIBLE		1999
#elif _POSIX_C_SOURCE >= 199506
#define	__POSIX_VISIBLE		199506
#define	__ISO_C_VISIBLE		1990
#elif _POSIX_C_SOURCE >= 199309
#define	__POSIX_VISIBLE		199309
#define	__ISO_C_VISIBLE		1990
#elif _POSIX_C_SOURCE >= 199209
#define	__POSIX_VISIBLE		199209
#define	__ISO_C_VISIBLE		1990
#elif _POSIX_C_SOURCE >= 199009
#define	__POSIX_VISIBLE		199009
#define	__ISO_C_VISIBLE		1990
#else
#define	__POSIX_VISIBLE		198808
#define	__ISO_C_VISIBLE		0
#endif /* _POSIX_C_SOURCE */

/*
 * When we've explicitly asked for a newer C version, make the C variable
 * visible by default. Also honor the glibc _ISOC{11,23}_SOURCE macros
 * extensions. Both glibc and OpenBSD do this, even when a more strict
 * _POSIX_C_SOURCE has been requested, and it makes good sense (especially for
 * pre POSIX 2024, since C11 is much nicer than the old C99 base). Continue the
 * practice with C23, though don't do older standards. Also, GLIBC doesn't have
 * a _ISOC17_SOURCE, so it's not implemented here. glibc has earlier ISOCxx defines,
 * but we don't implement those as they are not relevant enough.
 */
#if _ISOC23_SOURCE || (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L)
#undef __ISO_C_VISIBLE
#define __ISO_C_VISIBLE		2023
#elif _ISOC11_SOURCE || (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L)
#undef __ISO_C_VISIBLE
#define __ISO_C_VISIBLE		2011
#endif
#else /* _POSIX_C_SOURCE */
/*-
 * Deal with _ANSI_SOURCE:
 * If it is defined, and no other compilation environment is explicitly
 * requested, then define our internal feature-test macros to zero.  This
 * makes no difference to the preprocessor (undefined symbols in preprocessing
 * expressions are defined to have value zero), but makes it more convenient for
 * a test program to print out the values.
 *
 * If a program mistakenly defines _ANSI_SOURCE and some other macro such as
 * _POSIX_C_SOURCE, we will assume that it wants the broader compilation
 * environment (and in fact we will never get here).
 */
#if defined(_ANSI_SOURCE)	/* Hide almost everything. */
#define	__POSIX_VISIBLE		0
#define	__XSI_VISIBLE		0
#define	__BSD_VISIBLE		0
#define	__ISO_C_VISIBLE		1990
#define	__EXT1_VISIBLE		0
#elif defined(_C99_SOURCE)	/* Localism to specify strict C99 env. */
#define	__POSIX_VISIBLE		0
#define	__XSI_VISIBLE		0
#define	__BSD_VISIBLE		0
#define	__ISO_C_VISIBLE		1999
#define	__EXT1_VISIBLE		0
#elif defined(_C11_SOURCE)	/* Localism to specify strict C11 env. */
#define	__POSIX_VISIBLE		0
#define	__XSI_VISIBLE		0
#define	__BSD_VISIBLE		0
#define	__ISO_C_VISIBLE		2011
#define	__EXT1_VISIBLE		0
#elif defined(_C23_SOURCE)	/* Localism to specify strict C23 env. */
#define	__POSIX_VISIBLE		0
#define	__XSI_VISIBLE		0
#define	__BSD_VISIBLE		0
#define	__ISO_C_VISIBLE		2023
#define	__EXT1_VISIBLE		0
#else				/* Default environment: show everything. */
#define	__POSIX_VISIBLE		202405
#define	__XSI_VISIBLE		800
#define	__BSD_VISIBLE		1
#define	__ISO_C_VISIBLE		2023
#define	__EXT1_VISIBLE		1
#endif
#endif /* _POSIX_C_SOURCE */

/* User override __EXT1_VISIBLE */
#if defined(__STDC_WANT_LIB_EXT1__)
#undef	__EXT1_VISIBLE
#if __STDC_WANT_LIB_EXT1__
#define	__EXT1_VISIBLE		1
#else
#define	__EXT1_VISIBLE		0
#endif
#endif /* __STDC_WANT_LIB_EXT1__ */

#endif /* !_SYS__VISIBLE_H_ */