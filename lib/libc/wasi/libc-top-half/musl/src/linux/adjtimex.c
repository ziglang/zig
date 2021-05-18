#include <sys/timex.h>
#include <time.h>

int adjtimex(struct timex *tx)
{
	return clock_adjtime(CLOCK_REALTIME, tx);
}
