#include "time32.h"
#include <time.h>

struct tm *__gmtime32_r(time32_t *t, struct tm *tm)
{
	return gmtime_r(&(time_t){*t}, tm);
}
