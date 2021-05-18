#include "time32.h"
#include <time.h>

struct tm *__localtime32_r(time32_t *t, struct tm *tm)
{
	return localtime_r(&(time_t){*t}, tm);
}
