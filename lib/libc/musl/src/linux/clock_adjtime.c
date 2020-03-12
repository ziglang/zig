#include <sys/timex.h>
#include <time.h>
#include <errno.h>
#include "syscall.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)

struct ktimex64 {
	unsigned modes;
	int :32;
	long long offset, freq, maxerror, esterror;
	int status;
	int :32;
	long long constant, precision, tolerance;
	long long time_sec, time_usec;
	long long tick, ppsfreq, jitter;
	int shift;
	int :32;
	long long stabil, jitcnt, calcnt, errcnt, stbcnt;
	int tai;
	int __padding[11];
};

struct ktimex {
	unsigned modes;
	long offset, freq, maxerror, esterror;
	int status;
	long constant, precision, tolerance;
	long time_sec, time_usec;
	long tick, ppsfreq, jitter;
	int shift;
	long stabil, jitcnt, calcnt, errcnt, stbcnt;
	int tai;
	int __padding[11];
};

int clock_adjtime (clockid_t clock_id, struct timex *utx)
{
	int r = -ENOSYS;
#ifdef SYS_clock_adjtime64
	if (SYS_clock_adjtime == SYS_clock_adjtime64 ||
	    (utx->modes & ADJ_SETOFFSET) && !IS32BIT(utx->time.tv_sec)) {
		struct ktimex64 ktx = {
			.modes = utx->modes,
			.offset = utx->offset,
			.freq = utx->freq,
			.maxerror = utx->maxerror,
			.esterror = utx->esterror,
			.status = utx->status,
			.constant = utx->constant,
			.precision = utx->precision,
			.tolerance = utx->tolerance,
			.time_sec = utx->time.tv_sec,
			.time_usec = utx->time.tv_usec,
			.tick = utx->tick,
			.ppsfreq = utx->ppsfreq,
			.jitter = utx->jitter,
			.shift = utx->shift,
			.stabil = utx->stabil,
			.jitcnt = utx->jitcnt,
			.calcnt = utx->calcnt,
			.errcnt = utx->errcnt,
			.stbcnt = utx->stbcnt,
			.tai = utx->tai,
		};
		r = __syscall(SYS_clock_adjtime, clock_id, &ktx);
		if (r>=0) {
			utx->modes = ktx.modes;
			utx->offset = ktx.offset;
			utx->freq = ktx.freq;
			utx->maxerror = ktx.maxerror;
			utx->esterror = ktx.esterror;
			utx->status = ktx.status;
			utx->constant = ktx.constant;
			utx->precision = ktx.precision;
			utx->tolerance = ktx.tolerance;
			utx->time.tv_sec = ktx.time_sec;
			utx->time.tv_usec = ktx.time_usec;
			utx->tick = ktx.tick;
			utx->ppsfreq = ktx.ppsfreq;
			utx->jitter = ktx.jitter;
			utx->shift = ktx.shift;
			utx->stabil = ktx.stabil;
			utx->jitcnt = ktx.jitcnt;
			utx->calcnt = ktx.calcnt;
			utx->errcnt = ktx.errcnt;
			utx->stbcnt = ktx.stbcnt;
			utx->tai = ktx.tai;
		}
	}
	if (SYS_clock_adjtime == SYS_clock_adjtime64 || r!=-ENOSYS)
		return __syscall_ret(r);
	if ((utx->modes & ADJ_SETOFFSET) && !IS32BIT(utx->time.tv_sec))
		return __syscall_ret(-ENOTSUP);
#endif
	if (sizeof(time_t) > sizeof(long)) {
		struct ktimex ktx = {
			.modes = utx->modes,
			.offset = utx->offset,
			.freq = utx->freq,
			.maxerror = utx->maxerror,
			.esterror = utx->esterror,
			.status = utx->status,
			.constant = utx->constant,
			.precision = utx->precision,
			.tolerance = utx->tolerance,
			.time_sec = utx->time.tv_sec,
			.time_usec = utx->time.tv_usec,
			.tick = utx->tick,
			.ppsfreq = utx->ppsfreq,
			.jitter = utx->jitter,
			.shift = utx->shift,
			.stabil = utx->stabil,
			.jitcnt = utx->jitcnt,
			.calcnt = utx->calcnt,
			.errcnt = utx->errcnt,
			.stbcnt = utx->stbcnt,
			.tai = utx->tai,
		};
#ifdef SYS_adjtimex
		if (clock_id==CLOCK_REALTIME) r = __syscall(SYS_adjtimex, &ktx);
		else
#endif
		r = __syscall(SYS_clock_adjtime, clock_id, &ktx);
		if (r>=0) {
			utx->modes = ktx.modes;
			utx->offset = ktx.offset;
			utx->freq = ktx.freq;
			utx->maxerror = ktx.maxerror;
			utx->esterror = ktx.esterror;
			utx->status = ktx.status;
			utx->constant = ktx.constant;
			utx->precision = ktx.precision;
			utx->tolerance = ktx.tolerance;
			utx->time.tv_sec = ktx.time_sec;
			utx->time.tv_usec = ktx.time_usec;
			utx->tick = ktx.tick;
			utx->ppsfreq = ktx.ppsfreq;
			utx->jitter = ktx.jitter;
			utx->shift = ktx.shift;
			utx->stabil = ktx.stabil;
			utx->jitcnt = ktx.jitcnt;
			utx->calcnt = ktx.calcnt;
			utx->errcnt = ktx.errcnt;
			utx->stbcnt = ktx.stbcnt;
			utx->tai = ktx.tai;
		}
		return __syscall_ret(r);
	}
#ifdef SYS_adjtimex
	if (clock_id==CLOCK_REALTIME) return syscall(SYS_adjtimex, utx);
#endif
	return syscall(SYS_clock_adjtime, clock_id, utx);
}
