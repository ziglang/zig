#define _GNU_SOURCE
#include "time32.h"
#include <time.h>
#include <errno.h>
#include <stdint.h>

time32_t __time32gm(struct tm *tm)
{
	time_t t = timegm(tm);
	if (t < INT32_MIN || t > INT32_MAX) {
		errno = EOVERFLOW;
		return -1;
	}
	return t;
}
