#include <sys/timeb.h>
#include <time.h>

int ftime(struct timeb *tp)
{
	struct timespec ts;
	clock_gettime(CLOCK_REALTIME, &ts);
	tp->time = ts.tv_sec;
	tp->millitm = ts.tv_nsec / 1000000;
	tp->timezone = tp->dstflag = 0;
	return 0;
}
