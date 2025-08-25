#include "time32.h"
#include <time.h>

char *__ctime32(time32_t *t)
{
	return ctime(&(time_t){*t});
}
