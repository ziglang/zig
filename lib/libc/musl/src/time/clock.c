#include <time.h>
#include <limits.h>

clock_t clock()
{
	struct timespec ts;

	if (__clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts))
		return -1;

	if (ts.tv_sec > LONG_MAX/1000000
	 || ts.tv_nsec/1000 > LONG_MAX-1000000*ts.tv_sec)
		return -1;

	return ts.tv_sec*1000000 + ts.tv_nsec/1000;
}
