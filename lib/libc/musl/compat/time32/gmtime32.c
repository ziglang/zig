#include "time32.h"
#include <time.h>

struct tm *__gmtime32(time32_t *t)
{
	return gmtime(&(time_t){*t});
}
