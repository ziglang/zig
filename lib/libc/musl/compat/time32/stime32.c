#define _GNU_SOURCE
#include "time32.h"
#include <time.h>

int __stime32(const time32_t *t)
{
	return stime(&(time_t){*t});
}
