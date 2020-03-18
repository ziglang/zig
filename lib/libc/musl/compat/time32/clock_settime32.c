#include "time32.h"
#include <time.h>

int __clock_settime32(clockid_t clk, const struct timespec32 *ts32)
{
	return clock_settime(clk, (&(struct timespec){
		.tv_sec = ts32->tv_sec,
		.tv_nsec = ts32->tv_nsec}));
}
