/*
 * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*	$NetBSD: syslimits.h,v 1.15 1997/06/25 00:48:09 lukem Exp $	*/

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
 *	@(#)syslimits.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _SYS_SYSLIMITS_H_
#define _SYS_SYSLIMITS_H_

#include <sys/cdefs.h>

#if !defined(_ANSI_SOURCE)

/* max bytes for an exec function */
#if defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)
#define ARG_MAX           (1024 * 1024)
#else
#define ARG_MAX            (256 * 1024)
#endif

/*
 * Note: CHILD_MAX *must* be less than hard_maxproc, which is set at
 * compile time; you *cannot* set it higher than the hard limit!!
 */

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define CHILD_MAX                  266  /* max simultaneous processes */
#define GID_MAX            2147483647U  /* max value for a gid_t (2^31-2) */
#endif /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
#define LINK_MAX                32767   /* max file link count */
#define MAX_CANON                1024   /* max bytes in term canon input line */
#define MAX_INPUT                1024   /* max bytes in terminal input */
#define NAME_MAX                  255   /* max bytes in a file name */
#define NGROUPS_MAX                16   /* max supplemental group id's */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#define UID_MAX            2147483647U  /* max value for a uid_t (2^31-2) */

#define OPEN_MAX                10240   /* max open files per process - todo, make a config option? */

#endif /* (_POSIX_C_SOURCE && !_DARWIN_C_SOURCE) */
#define PATH_MAX                 1024   /* max bytes in pathname */
#define PIPE_BUF                  512   /* max bytes for atomic pipe writes */

#define BC_BASE_MAX                99   /* max ibase/obase values in bc(1) */
#define BC_DIM_MAX               2048   /* max array elements in bc(1) */
#define BC_SCALE_MAX               99   /* max scale value in bc(1) */
#define BC_STRING_MAX            1000   /* max const string length in bc(1) */
#define CHARCLASS_NAME_MAX         14   /* max character class name size */
#define COLL_WEIGHTS_MAX            2   /* max weights for order keyword */
#define EQUIV_CLASS_MAX             2
#define EXPR_NEST_MAX              32   /* max expressions nested in expr(1) */
#define LINE_MAX                 2048   /* max bytes in an input line */
#define RE_DUP_MAX                255   /* max RE's in interval notation */

#if __DARWIN_UNIX03
#define NZERO                      20   /* default priority [XSI] */
                                        /* = ((PRIO_MAX - PRIO_MIN) / 2) + 1 */
                                        /* range: 0 - 39 [(2 * NZERO) - 1] */
                                        /* 0 is not actually used */
#else /* !__DARWIN_UNIX03 */
#define NZERO                       0   /* default priority */
                                        /* range: -20 - 20 */
                                        /* (PRIO_MIN - PRIO_MAX) */
#endif /* __DARWIN_UNIX03 */
#endif /* !_ANSI_SOURCE */

#endif /* !_SYS_SYSLIMITS_H_ */
