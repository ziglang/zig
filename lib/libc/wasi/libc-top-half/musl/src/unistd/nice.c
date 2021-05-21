#include <unistd.h>
#include <sys/resource.h>
#include <limits.h>
#include "syscall.h"

int nice(int inc)
{
	int prio = inc;
	// Only query old priority if it can affect the result.
	// This also avoids issues with integer overflow.
	if (inc > -2*NZERO && inc < 2*NZERO)
		prio += getpriority(PRIO_PROCESS, 0);
	if (prio > NZERO-1) prio = NZERO-1;
	if (prio < -NZERO) prio = -NZERO;
	return setpriority(PRIO_PROCESS, 0, prio) ? -1 : prio;
}
