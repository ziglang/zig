/*
 * Copyright (c) 2000-2006 Apple Computer, Inc. All rights reserved.
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
/* Copyright (c) 1995 NeXT Computer, Inc. All Rights Reserved */
/*
 * Copyright (c) 1982, 1986, 1993
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
 *	@(#)time.h	8.2 (Berkeley) 7/10/94
 */

#ifndef _SYS_TIME_H_
#define _SYS_TIME_H_

#include <sys/cdefs.h>
#include <sys/_types.h>
#include <Availability.h>


/*
 * [XSI] The fd_set type shall be defined as described in <sys/select.h>.
 * The timespec structure shall be defined as described in <time.h>
 */
#include <sys/_types/_fd_def.h>
#include <sys/_types/_timespec.h>
#include <sys/_types/_timeval.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <sys/_types/_timeval64.h>
#endif /* !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE) */


#include <sys/_types/_time_t.h>
#include <sys/_types/_suseconds_t.h>

/*
 * Structure used as a parameter by getitimer(2) and setitimer(2) system
 * calls.
 */
struct  itimerval {
	struct  timeval it_interval;    /* timer interval */
	struct  timeval it_value;       /* current value */
};

/*
 * Names of the interval timers, and structure
 * defining a timer setting.
 */
#define ITIMER_REAL     0
#define ITIMER_VIRTUAL  1
#define ITIMER_PROF     2

/*
 * Select uses bit masks of file descriptors in longs.  These macros
 * manipulate such bit fields (the filesystem macros use chars).  The
 * extra protection here is to permit application redefinition above
 * the default size.
 */
#include <sys/_types/_fd_setsize.h>
#include <sys/_types/_fd_set.h>
#include <sys/_types/_fd_clr.h>
#include <sys/_types/_fd_isset.h>
#include <sys/_types/_fd_zero.h>

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)

#include <sys/_types/_fd_copy.h>

#define TIMEVAL_TO_TIMESPEC(tv, ts) {                                   \
	(ts)->tv_sec = (tv)->tv_sec;                                    \
	(ts)->tv_nsec = (tv)->tv_usec * 1000;                           \
}
#define TIMESPEC_TO_TIMEVAL(tv, ts) {                                   \
	(tv)->tv_sec = (ts)->tv_sec;                                    \
	(tv)->tv_usec = (ts)->tv_nsec / 1000;                           \
}

struct timezone {
	int     tz_minuteswest; /* minutes west of Greenwich */
	int     tz_dsttime;     /* type of dst correction */
};
#define DST_NONE        0       /* not on dst */
#define DST_USA         1       /* USA style dst */
#define DST_AUST        2       /* Australian style dst */
#define DST_WET         3       /* Western European dst */
#define DST_MET         4       /* Middle European dst */
#define DST_EET         5       /* Eastern European dst */
#define DST_CAN         6       /* Canada */

/* Operations on timevals. */
#define timerclear(tvp)         (tvp)->tv_sec = (tvp)->tv_usec = 0
#define timerisset(tvp)         ((tvp)->tv_sec || (tvp)->tv_usec)
#define timercmp(tvp, uvp, cmp)                                         \
	(((tvp)->tv_sec == (uvp)->tv_sec) ?                             \
	    ((tvp)->tv_usec cmp (uvp)->tv_usec) :                       \
	    ((tvp)->tv_sec cmp (uvp)->tv_sec))
#define timeradd(tvp, uvp, vvp)                                         \
	do {                                                            \
	        (vvp)->tv_sec = (tvp)->tv_sec + (uvp)->tv_sec;          \
	        (vvp)->tv_usec = (tvp)->tv_usec + (uvp)->tv_usec;       \
	        if ((vvp)->tv_usec >= 1000000) {                        \
	                (vvp)->tv_sec++;                                \
	                (vvp)->tv_usec -= 1000000;                      \
	        }                                                       \
	} while (0)
#define timersub(tvp, uvp, vvp)                                         \
	do {                                                            \
	        (vvp)->tv_sec = (tvp)->tv_sec - (uvp)->tv_sec;          \
	        (vvp)->tv_usec = (tvp)->tv_usec - (uvp)->tv_usec;       \
	        if ((vvp)->tv_usec < 0) {                               \
	                (vvp)->tv_sec--;                                \
	                (vvp)->tv_usec += 1000000;                      \
	        }                                                       \
	} while (0)

#define timevalcmp(l, r, cmp)   timercmp(l, r, cmp) /* freebsd */

/*
 * Getkerninfo clock information structure
 */
struct clockinfo {
	int     hz;             /* clock frequency */
	int     tick;           /* micro-seconds per hz tick */
	int     tickadj;        /* clock skew rate for adjtime() */
	int     stathz;         /* statistics clock frequency */
	int     profhz;         /* profiling clock frequency */
};
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */



#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
#include <time.h>
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

__BEGIN_DECLS

#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
int     adjtime(const struct timeval *, struct timeval *);
int     futimes(int, const struct timeval *);
int     lutimes(const char *, const struct timeval *) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);
int     settimeofday(const struct timeval *, const struct timezone *);
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

int     getitimer(int, struct itimerval *);
int     gettimeofday(struct timeval * __restrict, void * __restrict);

#include <sys/_select.h>        /* select() prototype */

int     setitimer(int, const struct itimerval * __restrict,
    struct itimerval * __restrict);
int     utimes(const char *, const struct timeval *);

__END_DECLS



#endif /* !_SYS_TIME_H_ */