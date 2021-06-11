#include "time_impl.h"
#include <errno.h>

struct tm *gmtime(const time_t *t)
{
	static struct tm tm;
	return __gmtime_r(t, &tm);
}
