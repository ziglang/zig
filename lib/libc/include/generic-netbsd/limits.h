/*	$NetBSD: limits.h,v 1.43.2.2 2024/10/11 17:26:32 martin Exp $	*/

/*
 * Copyright (c) 1988, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)limits.h	8.2 (Berkeley) 1/4/94
 */

#ifndef _LIMITS_H_
#define	_LIMITS_H_

#include <sys/featuretest.h>

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE) || \
    defined(_NETBSD_SOURCE)
#define	_POSIX_AIO_LISTIO_MAX	2
#define	_POSIX_AIO_MAX		1
#define	_POSIX_ARG_MAX		4096
#define	_POSIX_CHILD_MAX	25
#define	_POSIX_HOST_NAME_MAX	255
#define	_POSIX_LINK_MAX		8
#define	_POSIX_LOGIN_NAME_MAX	9
#define	_POSIX_MAX_CANON	255
#define	_POSIX_MAX_INPUT	255
#define	_POSIX_MQ_OPEN_MAX	8
#define	_POSIX_MQ_PRIO_MAX	32
#define	_POSIX_NAME_MAX		14
#define	_POSIX_NGROUPS_MAX	8
#define	_POSIX_OPEN_MAX		20
#define	_POSIX_PATH_MAX		256
#define	_POSIX_PIPE_BUF		512
#define	_POSIX_RE_DUP_MAX	255
#define	_POSIX_SSIZE_MAX	32767
#define	_POSIX_STREAM_MAX	8
#define	_POSIX_SYMLINK_MAX	255
#define	_POSIX_SYMLOOP_MAX	8

/*
 * Exact minimum values prescribed by:
 * Open Group Base Specifications Issue 7
 * https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/limits.h.html
 */
#define	_POSIX_THREAD_DESTRUCTOR_ITERATIONS	4
#define	_POSIX_THREAD_KEYS_MAX			128
#define	_POSIX_THREAD_THREADS_MAX		64

/*
 * Actual values used by libpthread, defined in terms of the above
 * except for PTHREAD_KEYS_MAX which is bigger than standard mandated
 * minimum value _POSIX_THREAD_KEYS_MAX, and PTHREAD_STACK_MIN which
 * doesn't have a defined name for the minimum value of zero.
 */
#define	PTHREAD_DESTRUCTOR_ITERATIONS 	_POSIX_THREAD_DESTRUCTOR_ITERATIONS
#define	PTHREAD_KEYS_MAX		256
#define	PTHREAD_STACK_MIN		4096 /* XXX MIN_PAGE_SIZE */
#define	PTHREAD_THREADS_MAX		_POSIX_THREAD_THREADS_MAX

#define	_POSIX_TIMER_MAX	32
#define	_POSIX_SEM_NSEMS_MAX	256
#define	_POSIX_SIGQUEUE_MAX	32
#define	_POSIX_REALTIME_SIGNALS	200112L
#define	_POSIX_DELAYTIMER_MAX	32
#define	_POSIX_TTY_NAME_MAX	9
#define	_POSIX_TZNAME_MAX	6

#define	_POSIX2_BC_BASE_MAX	99
#define	_POSIX2_BC_DIM_MAX	2048
#define	_POSIX2_BC_SCALE_MAX	99
#define	_POSIX2_BC_STRING_MAX	1000
#define	_POSIX2_CHARCLASS_NAME_MAX	14
#define	_POSIX2_COLL_WEIGHTS_MAX	2
#define	_POSIX2_EXPR_NEST_MAX	32
#define	_POSIX2_LINE_MAX	2048
#define	_POSIX2_RE_DUP_MAX	255

/*
 * X/Open CAE Specifications,
 * adopted in IEEE Std 1003.1-2001 XSI.
 */
#if (_POSIX_C_SOURCE - 0) >= 200112L || defined(_XOPEN_SOURCE) || \
    defined(_NETBSD_SOURCE)
#define	_XOPEN_IOV_MAX		16
#define	_XOPEN_NAME_MAX		256
#define	_XOPEN_PATH_MAX		1024

#define PASS_MAX		128		/* Legacy */

#define CHARCLASS_NAME_MAX	14
#define NL_ARGMAX		9
#define NL_LANGMAX		14
#define NL_MSGMAX		32767
#define NL_NMAX			1
#define NL_SETMAX		255
#define NL_TEXTMAX		2048

	/* IEEE Std 1003.1-2001 TSF */
#define	_GETGR_R_SIZE_MAX	1024
#define	_GETPW_R_SIZE_MAX	1024

/* Always ensure that this is consistent with <stdio.h> */
#ifndef TMP_MAX
#define TMP_MAX			308915776	/* Legacy */
#endif
#endif /* _POSIX_C_SOURCE >= 200112L || _XOPEN_SOURCE || _NETBSD_SOURCE */

/*
 * IEEE Std 1003.1-2024 (POSIX.1-2024)
 */
#if (_POSIX_C_SOURCE - 0) >= 202405L || (_XOPEN_SOURCE - 0) >= 800 || \
    defined(_NETBSD_SOURCE)
#define	GETENTROPY_MAX		256
#endif

#endif /* _POSIX_C_SOURCE || _XOPEN_SOURCE || _NETBSD_SOURCE */

#define MB_LEN_MAX		32	/* Allow ISO/IEC 2022 */

#include <machine/limits.h>

#ifdef __CHAR_UNSIGNED__
# define CHAR_MIN     0
# define CHAR_MAX     UCHAR_MAX
#else
# define CHAR_MIN     SCHAR_MIN
# define CHAR_MAX     SCHAR_MAX
#endif

#include <sys/syslimits.h>

#endif /* !_LIMITS_H_ */