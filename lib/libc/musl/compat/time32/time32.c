#include "time32.h"
#include <time.h>
#include <errno.h>
#include <stdint.h>

time32_t __time32(time32_t *p)
{
	time_t t = time(0);
	if (t < INT32_MIN || t > INT32_MAX) {
		errno = EOVERFLOW;
		return -1;
	}
	if (p) *p = t;
	return t;
}
