#include "time32.h"
#include <time.h>

char *__ctime32_r(time32_t *t, char *buf)
{
	return ctime_r(&(time_t){*t}, buf);
}
