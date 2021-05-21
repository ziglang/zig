#include <time.h>

char *ctime_r(const time_t *t, char *buf)
{
	struct tm tm, *tm_p = localtime_r(t, &tm);
	return tm_p ? asctime_r(tm_p, buf) : 0;
}
