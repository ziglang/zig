/*
 * Copyright (c) 2000, 2004-2007, 2009 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*	$NetBSD: limits.h,v 1.8 1996/10/21 05:10:50 jtc Exp $	*/

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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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

#include <sys/cdefs.h>
#include <machine/limits.h>
#include <sys/syslimits.h>

#if __DARWIN_C_LEVEL > __DARWIN_C_ANSI
#define	_POSIX_ARG_MAX		4096
#define	_POSIX_CHILD_MAX	25
#define	_POSIX_LINK_MAX		8
#define	_POSIX_MAX_CANON	255
#define	_POSIX_MAX_INPUT	255
#define	_POSIX_NAME_MAX		14
#define	_POSIX_NGROUPS_MAX	8
#define	_POSIX_OPEN_MAX		20
#define	_POSIX_PATH_MAX		256
#define	_POSIX_PIPE_BUF		512
#define	_POSIX_SSIZE_MAX	32767
#define	_POSIX_STREAM_MAX	8
#define	_POSIX_TZNAME_MAX	6

#define	_POSIX2_BC_BASE_MAX		99
#define	_POSIX2_BC_DIM_MAX		2048
#define	_POSIX2_BC_SCALE_MAX		99
#define	_POSIX2_BC_STRING_MAX		1000
#define	_POSIX2_EQUIV_CLASS_MAX		2
#define	_POSIX2_EXPR_NEST_MAX		32
#define	_POSIX2_LINE_MAX		2048
#define	_POSIX2_RE_DUP_MAX		255
#endif /* __DARWIN_C_LEVEL > __DARWIN_C_ANSI */

#if __DARWIN_C_LEVEL >= 199309L
#define _POSIX_AIO_LISTIO_MAX   2
#define _POSIX_AIO_MAX          1
#define _POSIX_DELAYTIMER_MAX   32
#define _POSIX_MQ_OPEN_MAX      8
#define _POSIX_MQ_PRIO_MAX	32
#define _POSIX_RTSIG_MAX 			8
#define _POSIX_SEM_NSEMS_MAX 			256
#define _POSIX_SEM_VALUE_MAX 			32767
#define _POSIX_SIGQUEUE_MAX 			32
#define _POSIX_TIMER_MAX 			32

#define _POSIX_CLOCKRES_MIN 20000000
#endif /* __DARWIN_C_LEVEL >= 199309L */

#if __DARWIN_C_LEVEL >= 199506L
#define _POSIX_THREAD_DESTRUCTOR_ITERATIONS 	4
#define _POSIX_THREAD_KEYS_MAX 			128
#define _POSIX_THREAD_THREADS_MAX 		64

#define PTHREAD_DESTRUCTOR_ITERATIONS 	4
#define PTHREAD_KEYS_MAX 		512
#if defined(__arm__) || defined(__arm64__)
#define PTHREAD_STACK_MIN 		16384
#else
#define PTHREAD_STACK_MIN 		8192
#endif
#endif /* __DARWIN_C_LEVEL >= 199506L */

#if __DARWIN_C_LEVEL >= 200112
#define _POSIX_HOST_NAME_MAX    255
#define _POSIX_LOGIN_NAME_MAX   9
#define _POSIX_SS_REPL_MAX 			4
#define _POSIX_SYMLINK_MAX 			255
#define _POSIX_SYMLOOP_MAX 			8
#define _POSIX_TRACE_EVENT_NAME_MAX 		30
#define _POSIX_TRACE_NAME_MAX 			8
#define _POSIX_TRACE_SYS_MAX 			8
#define _POSIX_TRACE_USER_EVENT_MAX 		32
#define _POSIX_TTY_NAME_MAX 			9
#define _POSIX2_CHARCLASS_NAME_MAX	14
#define	_POSIX2_COLL_WEIGHTS_MAX	2

#define _POSIX_RE_DUP_MAX 		_POSIX2_RE_DUP_MAX
#endif /* __DARWIN_C_LEVEL >= 200112 */

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define OFF_MIN		LLONG_MIN	/* min value for an off_t */
#define OFF_MAX		LLONG_MAX	/* max value for an off_t */
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

/* Actually for XSI Visible */
#if __DARWIN_C_LEVEL > __DARWIN_C_ANSI

/* Removed in Issue 6 */
#if !defined(_POSIX_C_SOURCE) || _POSIX_C_SOURCE < 200112L
#define PASS_MAX	128
#endif

#define NL_ARGMAX	9
#define NL_LANGMAX	14
#define NL_MSGMAX	32767
#define NL_NMAX		1
#define NL_SETMAX	255
#define NL_TEXTMAX	2048

#define _XOPEN_IOV_MAX	16
#define IOV_MAX		1024
#define _XOPEN_NAME_MAX 255
#define _XOPEN_PATH_MAX 1024

#endif /* __DARWIN_C_LEVEL > __DARWIN_C_ANSI */

/* NZERO to be defined here. TBD. See also sys/param.h  */

#endif /* !_LIMITS_H_ */