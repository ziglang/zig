/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
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

#include <sys/_timeval.h>
#include <sys/types.h>
#include <sys/timespec.h>
#include <sys/_clock_id.h>

struct timezone {
	int	tz_minuteswest;	/* minutes west of Greenwich */
	int	tz_dsttime;	/* type of dst correction */
};
#define	DST_NONE	0	/* not on dst */
#define	DST_USA		1	/* USA style dst */
#define	DST_AUST	2	/* Australian style dst */
#define	DST_WET		3	/* Western European dst */
#define	DST_MET		4	/* Middle European dst */
#define	DST_EET		5	/* Eastern European dst */
#define	DST_CAN		6	/* Canada */

#if __BSD_VISIBLE
struct bintime {
	time_t	sec;
	uint64_t frac;
};

static __inline void
bintime_addx(struct bintime *_bt, uint64_t _x)
{
	uint64_t _u;

	_u = _bt->frac;
	_bt->frac += _x;
	if (_u > _bt->frac)
		_bt->sec++;
}

static __inline void
bintime_add(struct bintime *_bt, const struct bintime *_bt2)
{
	uint64_t _u;

	_u = _bt->frac;
	_bt->frac += _bt2->frac;
	if (_u > _bt->frac)
		_bt->sec++;
	_bt->sec += _bt2->sec;
}

static __inline void
bintime_sub(struct bintime *_bt, const struct bintime *_bt2)
{
	uint64_t _u;

	_u = _bt->frac;
	_bt->frac -= _bt2->frac;
	if (_u < _bt->frac)
		_bt->sec--;
	_bt->sec -= _bt2->sec;
}

static __inline void
bintime_mul(struct bintime *_bt, u_int _x)
{
	uint64_t _p1, _p2;

	_p1 = (_bt->frac & 0xffffffffull) * _x;
	_p2 = (_bt->frac >> 32) * _x + (_p1 >> 32);
	_bt->sec *= _x;
	_bt->sec += (_p2 >> 32);
	_bt->frac = (_p2 << 32) | (_p1 & 0xffffffffull);
}

static __inline void
bintime_shift(struct bintime *_bt, int _exp)
{

	if (_exp > 0) {
		_bt->sec <<= _exp;
		_bt->sec |= _bt->frac >> (64 - _exp);
		_bt->frac <<= _exp;
	} else if (_exp < 0) {
		_bt->frac >>= -_exp;
		_bt->frac |= (uint64_t)_bt->sec << (64 + _exp);
		_bt->sec >>= -_exp;
	}
}

#define	bintime_clear(a)	((a)->sec = (a)->frac = 0)
#define	bintime_isset(a)	((a)->sec || (a)->frac)
#define	bintime_cmp(a, b, cmp)						\
	(((a)->sec == (b)->sec) ?					\
	    ((a)->frac cmp (b)->frac) :					\
	    ((a)->sec cmp (b)->sec))

#define	SBT_1S	((sbintime_t)1 << 32)
#define	SBT_1M	(SBT_1S * 60)
#define	SBT_1MS	(SBT_1S / 1000)
#define	SBT_1US	(SBT_1S / 1000000)
#define	SBT_1NS	(SBT_1S / 1000000000) /* beware rounding, see nstosbt() */
#define	SBT_MAX	0x7fffffffffffffffLL

static __inline int
sbintime_getsec(sbintime_t _sbt)
{

	return (_sbt >> 32);
}

static __inline sbintime_t
bttosbt(const struct bintime _bt)
{

	return (((sbintime_t)_bt.sec << 32) + (_bt.frac >> 32));
}

static __inline struct bintime
sbttobt(sbintime_t _sbt)
{
	struct bintime _bt;

	_bt.sec = _sbt >> 32;
	_bt.frac = _sbt << 32;
	return (_bt);
}

/*
 * Scaling functions for signed and unsigned 64-bit time using any
 * 32-bit fraction:
 */

static __inline int64_t
__stime64_scale32_ceil(int64_t x, int32_t factor, int32_t divisor)
{
	const int64_t rem = x % divisor;

	return (x / divisor * factor + (rem * factor + divisor - 1) / divisor);
}

static __inline int64_t
__stime64_scale32_floor(int64_t x, int32_t factor, int32_t divisor)
{
	const int64_t rem = x % divisor;

	return (x / divisor * factor + (rem * factor) / divisor);
}

static __inline uint64_t
__utime64_scale32_ceil(uint64_t x, uint32_t factor, uint32_t divisor)
{
	const uint64_t rem = x % divisor;

	return (x / divisor * factor + (rem * factor + divisor - 1) / divisor);
}

static __inline uint64_t
__utime64_scale32_floor(uint64_t x, uint32_t factor, uint32_t divisor)
{
	const uint64_t rem = x % divisor;

	return (x / divisor * factor + (rem * factor) / divisor);
}

/*
 * This function finds the common divisor between the two arguments,
 * in powers of two. Use a macro, so the compiler will output a
 * warning if the value overflows!
 *
 * Detailed description:
 *
 * Create a variable with 1's at the positions of the leading 0's
 * starting at the least significant bit, producing 0 if none (e.g.,
 * 01011000 -> 0000 0111). Then these two variables are bitwise AND'ed
 * together, to produce the greatest common power of two minus one. In
 * the end add one to flip the value to the actual power of two (e.g.,
 * 0000 0111 + 1 -> 0000 1000).
 */
#define	__common_powers_of_two(a, b) \
	((~(a) & ((a) - 1) & ~(b) & ((b) - 1)) + 1)

/*
 * Scaling functions for signed and unsigned 64-bit time assuming
 * reducable 64-bit fractions to 32-bit fractions:
 */

static __inline int64_t
__stime64_scale64_ceil(int64_t x, int64_t factor, int64_t divisor)
{
	const int64_t gcd = __common_powers_of_two(factor, divisor);

	return (__stime64_scale32_ceil(x, factor / gcd, divisor / gcd));
}

static __inline int64_t
__stime64_scale64_floor(int64_t x, int64_t factor, int64_t divisor)
{
	const int64_t gcd = __common_powers_of_two(factor, divisor);

	return (__stime64_scale32_floor(x, factor / gcd, divisor / gcd));
}

static __inline uint64_t
__utime64_scale64_ceil(uint64_t x, uint64_t factor, uint64_t divisor)
{
	const uint64_t gcd = __common_powers_of_two(factor, divisor);

	return (__utime64_scale32_ceil(x, factor / gcd, divisor / gcd));
}

static __inline uint64_t
__utime64_scale64_floor(uint64_t x, uint64_t factor, uint64_t divisor)
{
	const uint64_t gcd = __common_powers_of_two(factor, divisor);

	return (__utime64_scale32_floor(x, factor / gcd, divisor / gcd));
}

/*
 * Decimal<->sbt conversions. Multiplying or dividing by SBT_1NS
 * results in large roundoff errors which sbttons() and nstosbt()
 * avoid. Millisecond and microsecond functions are also provided for
 * completeness.
 *
 * When converting from sbt to another unit, the result is always
 * rounded down. When converting back to sbt the result is always
 * rounded up. This gives the property that sbttoX(Xtosbt(y)) == y .
 *
 * The conversion functions can also handle negative values.
 */
#define	SBT_DECLARE_CONVERSION_PAIR(name, units_per_second)	\
static __inline int64_t \
sbtto##name(sbintime_t sbt) \
{ \
	return (__stime64_scale64_floor(sbt, units_per_second, SBT_1S)); \
} \
static __inline sbintime_t \
name##tosbt(int64_t name) \
{ \
	return (__stime64_scale64_ceil(name, SBT_1S, units_per_second)); \
}

SBT_DECLARE_CONVERSION_PAIR(ns, 1000000000)
SBT_DECLARE_CONVERSION_PAIR(us, 1000000)
SBT_DECLARE_CONVERSION_PAIR(ms, 1000)

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

static __inline void
bintime2timespec(const struct bintime *_bt, struct timespec *_ts)
{

	_ts->tv_sec = _bt->sec;
	_ts->tv_nsec = __utime64_scale64_floor(
	    _bt->frac, 1000000000, 1ULL << 32) >> 32;
}

static __inline uint64_t
bintime2ns(const struct bintime *_bt)
{
	uint64_t ret;

	ret = (uint64_t)(_bt->sec) * (uint64_t)1000000000;
	ret += __utime64_scale64_floor(
	    _bt->frac, 1000000000, 1ULL << 32) >> 32;
	return (ret);
}

static __inline void
timespec2bintime(const struct timespec *_ts, struct bintime *_bt)
{

	_bt->sec = _ts->tv_sec;
	_bt->frac = __utime64_scale64_floor(
	    (uint64_t)_ts->tv_nsec << 32, 1ULL << 32, 1000000000);
}

static __inline void
bintime2timeval(const struct bintime *_bt, struct timeval *_tv)
{

	_tv->tv_sec = _bt->sec;
	_tv->tv_usec = __utime64_scale64_floor(
	    _bt->frac, 1000000, 1ULL << 32) >> 32;
}

static __inline void
timeval2bintime(const struct timeval *_tv, struct bintime *_bt)
{

	_bt->sec = _tv->tv_sec;
	_bt->frac = __utime64_scale64_floor(
	    (uint64_t)_tv->tv_usec << 32, 1ULL << 32, 1000000);
}

static __inline struct timespec
sbttots(sbintime_t _sbt)
{
	struct timespec _ts;

	_ts.tv_sec = _sbt >> 32;
	_ts.tv_nsec = sbttons((uint32_t)_sbt);
	return (_ts);
}

static __inline sbintime_t
tstosbt(struct timespec _ts)
{

	return (((sbintime_t)_ts.tv_sec << 32) + nstosbt(_ts.tv_nsec));
}

static __inline struct timeval
sbttotv(sbintime_t _sbt)
{
	struct timeval _tv;

	_tv.tv_sec = _sbt >> 32;
	_tv.tv_usec = sbttous((uint32_t)_sbt);
	return (_tv);
}

static __inline sbintime_t
tvtosbt(struct timeval _tv)
{

	return (((sbintime_t)_tv.tv_sec << 32) + ustosbt(_tv.tv_usec));
}
#endif /* __BSD_VISIBLE */

#ifdef _KERNEL
/*
 * Simple macros to convert ticks to milliseconds
 * or microseconds and vice-versa. The answer
 * will always be at least 1. Note the return
 * value is a uint32_t however we step up the
 * operations to 64 bit to avoid any overflow/underflow
 * problems.
 */
#define TICKS_2_MSEC(t) max(1, (uint32_t)(hz == 1000) ? \
	  (t) : (((uint64_t)(t) * (uint64_t)1000)/(uint64_t)hz))
#define TICKS_2_USEC(t) max(1, (uint32_t)(hz == 1000) ? \
	  ((t) * 1000) : (((uint64_t)(t) * (uint64_t)1000000)/(uint64_t)hz))
#define MSEC_2_TICKS(m) max(1, (uint32_t)((hz == 1000) ? \
	  (m) : ((uint64_t)(m) * (uint64_t)hz)/(uint64_t)1000))
#define USEC_2_TICKS(u) max(1, (uint32_t)((hz == 1000) ? \
	 ((u) / 1000) : ((uint64_t)(u) * (uint64_t)hz)/(uint64_t)1000000))

#endif
/* Operations on timespecs */
#define	timespecclear(tvp)	((tvp)->tv_sec = (tvp)->tv_nsec = 0)
#define	timespecisset(tvp)	((tvp)->tv_sec || (tvp)->tv_nsec)
#define	timespeccmp(tvp, uvp, cmp)					\
	(((tvp)->tv_sec == (uvp)->tv_sec) ?				\
	    ((tvp)->tv_nsec cmp (uvp)->tv_nsec) :			\
	    ((tvp)->tv_sec cmp (uvp)->tv_sec))

#define	timespecadd(tsp, usp, vsp)					\
	do {								\
		(vsp)->tv_sec = (tsp)->tv_sec + (usp)->tv_sec;		\
		(vsp)->tv_nsec = (tsp)->tv_nsec + (usp)->tv_nsec;	\
		if ((vsp)->tv_nsec >= 1000000000L) {			\
			(vsp)->tv_sec++;				\
			(vsp)->tv_nsec -= 1000000000L;			\
		}							\
	} while (0)
#define	timespecsub(tsp, usp, vsp)					\
	do {								\
		(vsp)->tv_sec = (tsp)->tv_sec - (usp)->tv_sec;		\
		(vsp)->tv_nsec = (tsp)->tv_nsec - (usp)->tv_nsec;	\
		if ((vsp)->tv_nsec < 0) {				\
			(vsp)->tv_sec--;				\
			(vsp)->tv_nsec += 1000000000L;			\
		}							\
	} while (0)
#define	timespecvalid_interval(tsp)	((tsp)->tv_sec >= 0 &&		\
	    (tsp)->tv_nsec >= 0 && (tsp)->tv_nsec < 1000000000L)

#ifdef _KERNEL

/* Operations on timevals. */

#define	timevalclear(tvp)		((tvp)->tv_sec = (tvp)->tv_usec = 0)
#define	timevalisset(tvp)		((tvp)->tv_sec || (tvp)->tv_usec)
#define	timevalcmp(tvp, uvp, cmp)					\
	(((tvp)->tv_sec == (uvp)->tv_sec) ?				\
	    ((tvp)->tv_usec cmp (uvp)->tv_usec) :			\
	    ((tvp)->tv_sec cmp (uvp)->tv_sec))

/* timevaladd and timevalsub are not inlined */

#endif /* _KERNEL */

#ifndef _KERNEL			/* NetBSD/OpenBSD compatible interfaces */

#define	timerclear(tvp)		((tvp)->tv_sec = (tvp)->tv_usec = 0)
#define	timerisset(tvp)		((tvp)->tv_sec || (tvp)->tv_usec)
#define	timercmp(tvp, uvp, cmp)					\
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
	} while (0)
#define	timersub(tvp, uvp, vvp)						\
	do {								\
		(vvp)->tv_sec = (tvp)->tv_sec - (uvp)->tv_sec;		\
		(vvp)->tv_usec = (tvp)->tv_usec - (uvp)->tv_usec;	\
		if ((vvp)->tv_usec < 0) {				\
			(vvp)->tv_sec--;				\
			(vvp)->tv_usec += 1000000;			\
		}							\
	} while (0)
#endif

/*
 * Names of the interval timers, and structure
 * defining a timer setting.
 */
#define	ITIMER_REAL	0
#define	ITIMER_VIRTUAL	1
#define	ITIMER_PROF	2

struct itimerval {
	struct	timeval it_interval;	/* timer interval */
	struct	timeval it_value;	/* current value */
};

/*
 * Getkerninfo clock information structure
 */
struct clockinfo {
	int	hz;		/* clock frequency */
	int	tick;		/* micro-seconds per hz tick */
	int	spare;
	int	stathz;		/* statistics clock frequency */
	int	profhz;		/* profiling clock frequency */
};

#if __BSD_VISIBLE
#define	CPUCLOCK_WHICH_PID	0
#define	CPUCLOCK_WHICH_TID	1
#endif

#if defined(_KERNEL) || defined(_STANDALONE)

/*
 * Kernel to clock driver interface.
 */
void	inittodr(time_t base);
void	resettodr(void);

extern volatile time_t	time_second;
extern volatile time_t	time_uptime;
extern struct bintime tc_tick_bt;
extern sbintime_t tc_tick_sbt;
extern time_t tick_seconds_max;
extern struct bintime tick_bt;
extern sbintime_t tick_sbt;
extern int tc_precexp;
extern int tc_timepercentage;
extern struct bintime bt_timethreshold;
extern struct bintime bt_tickthreshold;
extern sbintime_t sbt_timethreshold;
extern sbintime_t sbt_tickthreshold;

extern volatile int rtc_generation;

/*
 * Functions for looking at our clock: [get]{bin,nano,micro}[up]time()
 *
 * Functions without the "get" prefix returns the best timestamp
 * we can produce in the given format.
 *
 * "bin"   == struct bintime  == seconds + 64 bit fraction of seconds.
 * "nano"  == struct timespec == seconds + nanoseconds.
 * "micro" == struct timeval  == seconds + microseconds.
 *
 * Functions containing "up" returns time relative to boot and
 * should be used for calculating time intervals.
 *
 * Functions without "up" returns UTC time.
 *
 * Functions with the "get" prefix returns a less precise result
 * much faster than the functions without "get" prefix and should
 * be used where a precision of 1/hz seconds is acceptable or where
 * performance is priority. (NB: "precision", _not_ "resolution" !)
 */

void	binuptime(struct bintime *bt);
void	nanouptime(struct timespec *tsp);
void	microuptime(struct timeval *tvp);

static __inline sbintime_t
sbinuptime(void)
{
	struct bintime _bt;

	binuptime(&_bt);
	return (bttosbt(_bt));
}

void	bintime(struct bintime *bt);
void	nanotime(struct timespec *tsp);
void	microtime(struct timeval *tvp);

void	getbinuptime(struct bintime *bt);
void	getnanouptime(struct timespec *tsp);
void	getmicrouptime(struct timeval *tvp);

static __inline sbintime_t
getsbinuptime(void)
{
	struct bintime _bt;

	getbinuptime(&_bt);
	return (bttosbt(_bt));
}

void	getbintime(struct bintime *bt);
void	getnanotime(struct timespec *tsp);
void	getmicrotime(struct timeval *tvp);

void	getboottime(struct timeval *boottime);
void	getboottimebin(struct bintime *boottimebin);

/* Other functions */
int	itimerdecr(struct itimerval *itp, int usec);
int	itimerfix(struct timeval *tv);
int	eventratecheck(struct timeval *, int *, int);
#define	ppsratecheck(t, c, m) eventratecheck(t, c, m)
int	ratecheck(struct timeval *, const struct timeval *);
void	timevaladd(struct timeval *t1, const struct timeval *t2);
void	timevalsub(struct timeval *t1, const struct timeval *t2);
int	tvtohz(struct timeval *tv);

/*
 * The following HZ limits allow the tvtohz() function
 * to only use integer computations.
 */
#define	HZ_MAXIMUM (INT_MAX / (1000000 >> 6)) /* 137kHz */
#define	HZ_MINIMUM 8 /* hz */

#define	TC_DEFAULTPERC		5

#define	BT2FREQ(bt)                                                     \
	(((uint64_t)0x8000000000000000 + ((bt)->frac >> 2)) /           \
	    ((bt)->frac >> 1))

#define	SBT2FREQ(sbt)	((SBT_1S + ((sbt) >> 1)) / (sbt))

#define	FREQ2BT(freq, bt)                                               \
{									\
	(bt)->sec = 0;                                                  \
	(bt)->frac = ((uint64_t)0x8000000000000000  / (freq)) << 1;     \
}

#define	TIMESEL(sbt, sbt2)						\
	(((sbt2) >= sbt_timethreshold) ?				\
	    ((*(sbt) = getsbinuptime()), 1) : ((*(sbt) = sbinuptime()), 0))

#else /* !_KERNEL && !_STANDALONE */
#include <time.h>

#include <sys/cdefs.h>
#include <sys/select.h>

__BEGIN_DECLS
int	setitimer(int, const struct itimerval *, struct itimerval *);
int	utimes(const char *, const struct timeval *);

#if __BSD_VISIBLE
int	adjtime(const struct timeval *, struct timeval *);
int	clock_getcpuclockid2(id_t, int, clockid_t *);
int	futimes(int, const struct timeval *);
int	futimesat(int, const char *, const struct timeval [2]);
int	lutimes(const char *, const struct timeval *);
int	settimeofday(const struct timeval *, const struct timezone *);
#endif

#if __XSI_VISIBLE
int	getitimer(int, struct itimerval *);
int	gettimeofday(struct timeval *, struct timezone *);
#endif

__END_DECLS

#endif /* !_KERNEL */

#endif /* !_SYS_TIME_H_ */