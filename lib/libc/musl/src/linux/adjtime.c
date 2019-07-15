#define _GNU_SOURCE
#include <sys/time.h>
#include <sys/timex.h>
#include <errno.h>
#include "syscall.h"

int adjtime(const struct timeval *in, struct timeval *out)
{
	struct timex tx = { 0 };
	if (in) {
		if (in->tv_sec > 1000 || in->tv_usec > 1000000000) {
			errno = EINVAL;
			return -1;
		}
		tx.offset = in->tv_sec*1000000 + in->tv_usec;
		tx.modes = ADJ_OFFSET_SINGLESHOT;
	}
	if (syscall(SYS_adjtimex, &tx) < 0) return -1;
	if (out) {
		out->tv_sec = tx.offset / 1000000;
		if ((out->tv_usec = tx.offset % 1000000) < 0) {
			out->tv_sec--;
			out->tv_usec += 1000000;
		}
	}
	return 0;
}
