#include "time32.h"
#include <time.h>
#include <sys/timex.h>

struct timex32;

int __adjtimex_time32(struct timex32 *tx32)
{
	return __clock_adjtime32(CLOCK_REALTIME, tx32);
}
