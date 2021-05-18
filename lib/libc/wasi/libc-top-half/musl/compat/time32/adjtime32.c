#define _GNU_SOURCE
#include "time32.h"
#include <time.h>
#include <sys/time.h>
#include <sys/timex.h>

int __adjtime32(const struct timeval32 *in32, struct timeval32 *out32)
{
	struct timeval out;
	int r = adjtime((&(struct timeval){
		.tv_sec = in32->tv_sec,
		.tv_usec = in32->tv_usec}), &out);
	if (r) return r;
	/* We can't range-check the result because success was already
	 * committed by the above call. */
	if (out32) {
		out32->tv_sec = out.tv_sec;
		out32->tv_usec = out.tv_usec;
	}
	return r;
}
