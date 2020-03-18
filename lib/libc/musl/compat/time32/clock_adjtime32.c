#include "time32.h"
#include <time.h>
#include <sys/time.h>
#include <sys/timex.h>
#include <string.h>
#include <stddef.h>

struct timex32 {
	unsigned modes;
	long offset, freq, maxerror, esterror;
	int status;
	long constant, precision, tolerance;
	struct timeval32 time;
	long tick, ppsfreq, jitter;
	int shift;
	long stabil, jitcnt, calcnt, errcnt, stbcnt;
	int tai;
	int __padding[11];
};

int __clock_adjtime32(clockid_t clock_id, struct timex32 *tx32)
{
	struct timex utx = {
		.modes = tx32->modes,
		.offset = tx32->offset,
		.freq = tx32->freq,
		.maxerror = tx32->maxerror,
		.esterror = tx32->esterror,
		.status = tx32->status,
		.constant = tx32->constant,
		.precision = tx32->precision,
		.tolerance = tx32->tolerance,
		.time.tv_sec = tx32->time.tv_sec,
		.time.tv_usec = tx32->time.tv_usec,
		.tick = tx32->tick,
		.ppsfreq = tx32->ppsfreq,
		.jitter = tx32->jitter,
		.shift = tx32->shift,
		.stabil = tx32->stabil,
		.jitcnt = tx32->jitcnt,
		.calcnt = tx32->calcnt,
		.errcnt = tx32->errcnt,
		.stbcnt = tx32->stbcnt,
		.tai = tx32->tai,
	};
	int r = clock_adjtime(clock_id, &utx);
	if (r<0) return r;
	tx32->modes = utx.modes;
	tx32->offset = utx.offset;
	tx32->freq = utx.freq;
	tx32->maxerror = utx.maxerror;
	tx32->esterror = utx.esterror;
	tx32->status = utx.status;
	tx32->constant = utx.constant;
	tx32->precision = utx.precision;
	tx32->tolerance = utx.tolerance;
	tx32->time.tv_sec = utx.time.tv_sec;
	tx32->time.tv_usec = utx.time.tv_usec;
	tx32->tick = utx.tick;
	tx32->ppsfreq = utx.ppsfreq;
	tx32->jitter = utx.jitter;
	tx32->shift = utx.shift;
	tx32->stabil = utx.stabil;
	tx32->jitcnt = utx.jitcnt;
	tx32->calcnt = utx.calcnt;
	tx32->errcnt = utx.errcnt;
	tx32->stbcnt = utx.stbcnt;
	tx32->tai = utx.tai;
	return r;
}
