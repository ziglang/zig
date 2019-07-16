#include "time_impl.h"

struct tm *localtime(const time_t *t)
{
	static struct tm tm;
	return __localtime_r(t, &tm);
}
