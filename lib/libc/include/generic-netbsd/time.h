/*	$NetBSD: time.h,v 1.48 2022/10/23 15:43:40 jschauma Exp $	*/

/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	@(#)time.h	8.3 (Berkeley) 1/21/94
 */

#ifndef _TIME_H_
#define	_TIME_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <machine/ansi.h>

#include <sys/null.h>

#ifdef	_BSD_CLOCK_T_
typedef	_BSD_CLOCK_T_	clock_t;
#undef	_BSD_CLOCK_T_
#endif

#ifdef	_BSD_TIME_T_
typedef	_BSD_TIME_T_	time_t;
#undef	_BSD_TIME_T_
#endif

#ifdef	_BSD_SIZE_T_
typedef	_BSD_SIZE_T_	size_t;
#undef	_BSD_SIZE_T_
#endif

#ifdef	_BSD_CLOCKID_T_
typedef	_BSD_CLOCKID_T_	clockid_t;
#undef	_BSD_CLOCKID_T_
#endif

#ifdef	_BSD_TIMER_T_
typedef	_BSD_TIMER_T_	timer_t;
#undef	_BSD_TIMER_T_
#endif

#define CLOCKS_PER_SEC	100

struct tm {
	int	tm_sec;		/* seconds after the minute [0-60] */
	int	tm_min;		/* minutes after the hour [0-59] */
	int	tm_hour;	/* hours since midnight [0-23] */
	int	tm_mday;	/* day of the month [1-31] */
	int	tm_mon;		/* months since January [0-11] */
	int	tm_year;	/* years since 1900 */
	int	tm_wday;	/* days since Sunday [0-6] */
	int	tm_yday;	/* days since January 1 [0-365] */
	int	tm_isdst;	/* Daylight Savings Time flag */
	long	tm_gmtoff;	/* offset from UTC in seconds */
	__aconst char *tm_zone;	/* timezone abbreviation */
};

__BEGIN_DECLS
char *asctime(const struct tm *);
clock_t clock(void);
#ifndef __LIBC12_SOURCE__
char *ctime(const time_t *) __RENAME(__ctime50);
double difftime(time_t, time_t) __RENAME(__difftime50);
struct tm *gmtime(const time_t *) __RENAME(__gmtime50);
struct tm *localtime(const time_t *) __RENAME(__locatime50);
time_t time(time_t *) __RENAME(__time50);
time_t mktime(struct tm *) __RENAME(__mktime50);
#endif
size_t strftime(char * __restrict, size_t, const char * __restrict,
    const struct tm * __restrict)
    __attribute__((__format__(__strftime__, 3, 0)));

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE) || \
    defined(_NETBSD_SOURCE)
#ifndef __LIBC12_SOURCE__
/*
 * CLK_TCK uses libc's internal __sysconf() to retrieve the machine's
 * HZ. The value of _SC_CLK_TCK is 39 -- we hard code it so we do not
 * need to include unistd.h
 */
long __sysconf(int);
#define CLK_TCK		(__sysconf(39))
#endif
#endif

extern __aconst char *tzname[2];
#ifndef __LIBC12_SOURCE__
void tzset(void) __RENAME(__tzset50);
#endif

/*
 * X/Open Portability Guide >= Issue 4
 */
#if defined(_XOPEN_SOURCE) || defined(_NETBSD_SOURCE)
extern int daylight;
#ifndef __LIBC12_SOURCE__
extern long int timezone __RENAME(__timezone13);
#endif
char *strptime(const char * __restrict, const char * __restrict,
    struct tm * __restrict);
#endif

#if (defined(_XOPEN_SOURCE) && defined(_XOPEN_SOURCE_EXTENDED)) || \
    defined(_NETBSD_SOURCE)
struct tm *getdate(const char *);
extern int getdate_err;
#endif

/* ISO/IEC 9899:201x 7.27.1/3 Components of time */
#include <sys/timespec.h>

#if (_POSIX_C_SOURCE - 0) >= 199309L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
#include <sys/time.h>
struct sigevent;
struct itimerspec;
int clock_nanosleep(clockid_t, int, const struct timespec *, struct timespec *);
#ifndef __LIBC12_SOURCE__
int clock_getres(clockid_t, struct timespec *)
    __RENAME(__clock_getres50);
int clock_gettime(clockid_t, struct timespec *)
    __RENAME(__clock_gettime50);
int clock_settime(clockid_t, const struct timespec *)
    __RENAME(__clock_settime50);
int nanosleep(const struct timespec *, struct timespec *)
    __RENAME(__nanosleep50);
int timer_gettime(timer_t, struct itimerspec *) __RENAME(__timer_gettime50);
int timer_settime(timer_t, int, const struct itimerspec * __restrict, 
    struct itimerspec * __restrict) __RENAME(__timer_settime50);
#endif
#ifdef _NETBSD_SOURCE
#include <sys/idtype.h>
int clock_getcpuclockid2(idtype_t, id_t, clockid_t *);
#endif
int clock_getcpuclockid(pid_t, clockid_t *);

int timer_create(clockid_t, struct sigevent * __restrict,
    timer_t * __restrict);
int timer_delete(timer_t);
int timer_getoverrun(timer_t);
#endif /* _POSIX_C_SOURCE >= 199309 || _XOPEN_SOURCE >= 500 || ... */

#if (_POSIX_C_SOURCE - 0) >= 199506L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_REENTRANT) || defined(_NETBSD_SOURCE)
char *asctime_r(const struct tm * __restrict, char * __restrict);
#ifndef __LIBC12_SOURCE__
char *ctime_r(const time_t *, char *) __RENAME(__ctime_r50);
struct tm *gmtime_r(const time_t * __restrict, struct tm * __restrict)
    __RENAME(__gmtime_r50);
struct tm *localtime_r(const time_t * __restrict, struct tm * __restrict)
    __RENAME(__localtime_r50);
#endif
#endif

#if (_POSIX_C_SOURCE - 0) >= 200809L || defined(_NETBSD_SOURCE)
#  ifndef __LOCALE_T_DECLARED
typedef struct _locale		*locale_t;
#  define __LOCALE_T_DECLARED
#  endif
size_t strftime_l(char * __restrict, size_t, const char * __restrict,
    const struct tm * __restrict, locale_t)
    __attribute__((__format__(__strftime__, 3, 0)));
#endif

#if defined(_NETBSD_SOURCE)

typedef struct __state *timezone_t;

#ifndef __LIBC12_SOURCE__
time_t time2posix(time_t) __RENAME(__time2posix50);
time_t posix2time(time_t) __RENAME(__posix2time50);
time_t timegm(struct tm *) __RENAME(__timegm50);
time_t timeoff(struct tm *, long) __RENAME(__timeoff50);
time_t timelocal(struct tm *) __RENAME(__timelocal50);
struct tm *offtime(const time_t *, long) __RENAME(__offtime50);
void tzsetwall(void) __RENAME(__tzsetwall50);

struct tm *offtime_r(const time_t *, long, struct tm *) __RENAME(__offtime_r50);
struct tm *localtime_rz(timezone_t __restrict, const time_t * __restrict,
    struct tm * __restrict) __RENAME(__localtime_rz50);
char *ctime_rz(timezone_t __restrict, const time_t *, char *)
    __RENAME(__ctime_rz50);
time_t mktime_z(timezone_t __restrict, struct tm * __restrict)
    __RENAME(__mktime_z50);
time_t timelocal_z(timezone_t __restrict, struct tm *)
    __RENAME(__timelocal_z50);
time_t time2posix_z(timezone_t __restrict, time_t) __RENAME(__time2posix_z50);
time_t posix2time_z(timezone_t __restrict, time_t) __RENAME(__posix2time_z50);
timezone_t tzalloc(const char *) __RENAME(__tzalloc50);
void tzfree(timezone_t __restrict) __RENAME(__tzfree50);
const char *tzgetname(timezone_t __restrict, int) __RENAME(__tzgetname50);
long tzgetgmtoff(timezone_t __restrict, int) __RENAME(__tzgetgmtoff50);
#endif

size_t strftime_lz(timezone_t __restrict, char * __restrict, size_t,
    const char * __restrict, const struct tm * __restrict, locale_t)
    __attribute__((__format__(__strftime__, 4, 0)));
size_t strftime_z(timezone_t __restrict, char * __restrict, size_t,
    const char * __restrict, const struct tm * __restrict)
    __attribute__((__format__(__strftime__, 4, 0)));
char *strptime_l(const char * __restrict, const char * __restrict,
    struct tm * __restrict, locale_t);

#endif /* _NETBSD_SOURCE */

/* ISO/IEC 9899:201x 7.27.2.5 The timespec_get function */
#define TIME_UTC	1	/* time elapsed since epoch */
int timespec_get(struct timespec *ts, int base);

__END_DECLS

#endif /* !_TIME_H_ */