#include "time32.h"
#include <time.h>

double __difftime32(time32_t t1, time32_t t2)
{
	return difftime(t1, t2);
}
