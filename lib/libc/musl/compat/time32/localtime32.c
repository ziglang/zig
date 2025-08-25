#include "time32.h"
#include <time.h>

struct tm *__localtime32(time32_t *t)
{
	return localtime(&(time_t){*t});
}
