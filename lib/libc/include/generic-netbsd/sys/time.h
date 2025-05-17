/*	$NetBSD: time.h,v 1.80 2022/06/26 22:31:38 riastradh Exp $	*/

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
 *	@(#)time.h	8.5 (Berkeley) 5/4/95
 */

#ifndef _SYS_TIME_H_
#define	_SYS_TIME_H_

#include <sys/featuretest.h>
#include <sys/types.h>

/*
 * Structure returned by gettimeofday(2) system call,
 * and used in other calls.
 */
struct timeval {
	time_t    	tv_sec;		/* seconds */
	suseconds_t	tv_usec;	/* and microseconds */
};

#include <sys/timespec.h>

#if defined(_NETBSD_SOURCE)
#define	TIMEVAL_TO_TIMESPEC(tv, ts) do {				\
	(ts)->tv_sec = (tv)->tv_sec;					\
	(ts)->tv_nsec = (tv)->tv_usec * 1000;				\
} while (/*CONSTCOND*/0)
#define	TIMESPEC_TO_TIMEVAL(tv, ts) do {				\
	(tv)->tv_sec = (ts)->tv_sec;					\
	(tv)->tv_usec = (suseconds_t)(ts)->tv_nsec / 1000;		\
} while (/*CONSTCOND*/0)

/*
 * Note: timezone is obsolete. All timezone handling is now in
 * userland. Its just here for back compatibility.
 */
struct timezone {
	int	tz_minuteswest;	/* minutes west of Greenwich */
	int	tz_dsttime;	/* type of dst correction */
};

/* Operations on timevals. */
#define	timerclear(tvp)		(tvp)->tv_sec = (tvp)->tv_usec = 0L
#define	timerisset(tvp)		((tvp)->tv_sec || (tvp)->tv_usec)
#define	timercmp(tvp, uvp, cmp)						\
	(((tvp)->tv_sec == (uvp)->tv_sec) ?				\
	    ((tvp)->tv_usec cmp (uvp)->tv_usec) :			\
	    ((tvp)->tv_sec cmp (uvp)->tv_sec))
#define	timeradd(tvp, uvp, vvp)						\
	do {								\
		(vvp)->tv_sec = (tvp)->tv_sec + (uvp)->tv_sec;		\
		(vvp)->tv_usec = (tvp)->tv_usec + (uvp)->tv_usec;	\
		if ((vvp)->tv_usec >= 1000000) {			\
			(vvp)->tv_sec++;				\
			(vvp)->tv_usec -= 1000000;			\
		}							\
	} while (/* CONSTCOND */ 0)
#define	timersub(tvp, uvp, vvp)						\
	do {								\
		(vvp)->tv_sec = (tvp)->tv_sec - (uvp)->tv_sec;		\
		(vvp)->tv_usec = (tvp)->tv_usec - (uvp)->tv_usec;	\
		if ((vvp)->tv_usec < 0) {				\
			(vvp)->tv_sec--;				\
			(vvp)->tv_usec += 1000000;			\
		}							\
	} while (/* CONSTCOND */ 0)

/*
 * hide bintime for _STANDALONE because this header is used for hpcboot.exe,
 * which is built with compilers which don't recognize LL suffix.
 *	http://mail-index.NetBSD.org/tech-userlevel/2008/02/27/msg000181.html
 */
#if !defined(_STANDALONE)
struct bintime {
	time_t	sec;
	uint64_t frac;
};

static __inline void
bintime_addx(struct bintime *bt, uint64_t x)
{
	uint64_t u;

	u = bt->frac;
	bt->frac += x;
	if (u > bt->frac)
		bt->sec++;
}

static __inline void
bintime_add(struct bintime *bt, const struct bintime *bt2)
{
	uint64_t u;

	u = bt->frac;
	bt->frac += bt2->frac;
	if (u > bt->frac)
		bt->sec++;
	bt->sec += bt2->sec;
}

static __inline void
bintime_sub(struct bintime *bt, const struct bintime *bt2)
{
	uint64_t u;

	u = bt->frac;
	bt->frac -= bt2->frac;
	if (u < bt->frac)
		bt->sec--;
	bt->sec -= bt2->sec;
}

#define	bintimecmp(bta, btb, cmp)					\
	(((bta)->sec == (btb)->sec) ?					\
	    ((bta)->frac cmp (btb)->frac) :				\
	    ((bta)->sec cmp (btb)->sec))

/*-
 * Background information:
 *
 * When converting between timestamps on parallel timescales of differing
 * resolutions it is historical and scientific practice to round down rather
 * than doing 4/5 rounding.
 *
 *   The date changes at midnight, not at noon.
 *
 *   Even at 15:59:59.999999999 it's not four'o'clock.
 *
 *   time_second ticks after N.999999999 not after N.4999999999
 */

/*
 * The magic numbers for converting ms/us/ns to fractions
 */

/* 1ms = (2^64) / 1000       */
#define	BINTIME_SCALE_MS	((uint64_t)18446744073709551ULL)

/* 1us = (2^64) / 1000000    */
#define	BINTIME_SCALE_US	((uint64_t)18446744073709ULL)

/* 1ns = (2^64) / 1000000000 */
#define	BINTIME_SCALE_NS	((uint64_t)18446744073ULL)

static __inline void
bintime2timespec(const struct bintime *bt, struct timespec *ts)
{

	ts->tv_sec = bt->sec;
	ts->tv_nsec =
	    (long)((1000000000ULL * (uint32_t)(bt->frac >> 32)) >> 32);
}

static __inline void
timespec2bintime(const struct timespec *ts, struct bintime *bt)
{

	bt->sec = ts->tv_sec;
	bt->frac = (uint64_t)ts->tv_nsec * BINTIME_SCALE_NS;
}

static __inline void
bintime2timeval(const struct bintime *bt, struct timeval *tv)
{

	tv->tv_sec = bt->sec;
	tv->tv_usec =
	    (suseconds_t)((1000000ULL * (uint32_t)(bt->frac >> 32)) >> 32);
}

static __inline void
timeval2bintime(const struct timeval *tv, struct bintime *bt)
{

	bt->sec = tv->tv_sec;
	bt->frac = (uint64_t)tv->tv_usec * BINTIME_SCALE_US;
}

static __inline struct bintime
ms2bintime(uint64_t ms)
{
	struct bintime bt;

	bt.sec = (time_t)(ms / 1000U);
	bt.frac = (uint64_t)(ms % 1000U) * BINTIME_SCALE_MS;

	return bt;
}

static __inline struct bintime
us2bintime(uint64_t us)
{
	struct bintime bt;

	bt.sec = (time_t)(us / 1000000U);
	bt.frac = (uint64_t)(us % 1000000U) * BINTIME_SCALE_US;

	return bt;
}

static __inline struct bintime
ns2bintime(uint64_t ns)
{
	struct bintime bt;

	bt.sec = (time_t)(ns / 1000000000U);
	bt.frac = (uint64_t)(ns % 1000000000U) * BINTIME_SCALE_NS;

	return bt;
}
#endif /* !defined(_STANDALONE) */

/* Operations on timespecs. */
#define	timespecclear(tsp)	(tsp)->tv_sec = (time_t)((tsp)->tv_nsec = 0L)
#define	timespecisset(tsp)	((tsp)->tv_sec || (tsp)->tv_nsec)
#define	timespeccmp(tsp, usp, cmp)					\
	(((tsp)->tv_sec == (usp)->tv_sec) ?				\
	    ((tsp)->tv_nsec cmp (usp)->tv_nsec) :			\
	    ((tsp)->tv_sec cmp (usp)->tv_sec))
#define	timespecadd(tsp, usp, vsp)					\
	do {								\
		(vsp)->tv_sec = (tsp)->tv_sec + (usp)->tv_sec;		\
		(vsp)->tv_nsec = (tsp)->tv_nsec + (usp)->tv_nsec;	\
		if ((vsp)->tv_nsec >= 1000000000L) {			\
			(vsp)->tv_sec++;				\
			(vsp)->tv_nsec -= 1000000000L;			\
		}							\
	} while (/* CONSTCOND */ 0)
#define	timespecsub(tsp, usp, vsp)					\
	do {								\
		(vsp)->tv_sec = (tsp)->tv_sec - (usp)->tv_sec;		\
		(vsp)->tv_nsec = (tsp)->tv_nsec - (usp)->tv_nsec;	\
		if ((vsp)->tv_nsec < 0) {				\
			(vsp)->tv_sec--;				\
			(vsp)->tv_nsec += 1000000000L;			\
		}							\
	} while (/* CONSTCOND */ 0)
#define timespec2ns(x) (((uint64_t)(x)->tv_sec) * 1000000000L + (x)->tv_nsec)

#ifdef _KERNEL
bool timespecaddok(const struct timespec *, const struct timespec *) __pure;
bool timespecsubok(const struct timespec *, const struct timespec *) __pure;
#endif

#endif /* _NETBSD_SOURCE */

/*
 * Names of the interval timers, and structure
 * defining a timer setting.
 * NB: Must match the CLOCK_ constants below.
 */
#define	ITIMER_REAL		0
#define	ITIMER_VIRTUAL		1
#define	ITIMER_PROF		2
#define	ITIMER_MONOTONIC	3

struct	itimerval {
	struct	timeval it_interval;	/* timer interval */
	struct	timeval it_value;	/* current value */
};

/*
 * Structure defined by POSIX.1b to be like a itimerval, but with
 * timespecs. Used in the timer_*() system calls.
 */
struct	itimerspec {
	struct	timespec it_interval;
	struct	timespec it_value;
};

#define	CLOCK_REALTIME	0
#define	CLOCK_VIRTUAL	1
#define	CLOCK_PROF	2
#define	CLOCK_MONOTONIC	3
#define CLOCK_THREAD_CPUTIME_ID		0x20000000
#define CLOCK_PROCESS_CPUTIME_ID	0x40000000

#if defined(_NETBSD_SOURCE)
#define	TIMER_RELTIME	0x0	/* relative timer */
#endif
#define	TIMER_ABSTIME	0x1	/* absolute timer */

#ifdef _KERNEL
#include <sys/timevar.h>
#else /* !_KERNEL */
#ifndef _STANDALONE
#if (_POSIX_C_SOURCE - 0) >= 200112L || \
    (defined(_XOPEN_SOURCE) && defined(_XOPEN_SOURCE_EXTENDED)) || \
    (_XOPEN_SOURCE - 0) >= 500 || defined(_NETBSD_SOURCE)
#include <sys/select.h>
#endif

#include <sys/cdefs.h>
#include <time.h>

__BEGIN_DECLS
#ifndef __LIBC12_SOURCE__
#if (_POSIX_C_SOURCE - 0) >= 200112L || \
    defined(_XOPEN_SOURCE) || defined(_NETBSD_SOURCE)
int	getitimer(int, struct itimerval *) __RENAME(__getitimer50);
int	gettimeofday(struct timeval * __restrict, void *__restrict)
    __RENAME(__gettimeofday50);
int	setitimer(int, const struct itimerval * __restrict,
	    struct itimerval * __restrict) __RENAME(__setitimer50);
int	utimes(const char *, const struct timeval [2]) __RENAME(__utimes50);
#endif /* _POSIX_C_SOURCE >= 200112L || _XOPEN_SOURCE || _NETBSD_SOURCE */

#if defined(_NETBSD_SOURCE) || defined(HAVE_NBTOOL_CONFIG_H)
int	adjtime(const struct timeval *, struct timeval *) __RENAME(__adjtime50);
int	futimes(int, const struct timeval [2]) __RENAME(__futimes50);
int	lutimes(const char *, const struct timeval [2]) __RENAME(__lutimes50);
int	settimeofday(const struct timeval * __restrict,
	    const void *__restrict) __RENAME(__settimeofday50);
#endif /* _NETBSD_SOURCE */
#endif /* __LIBC12_SOURCE__ */
__END_DECLS

#endif	/* !_STANDALONE */
#endif /* !_KERNEL */
#endif /* !_SYS_TIME_H_ */