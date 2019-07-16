#include "stdio_impl.h"
#include "lock.h"

static FILE *ofl_head;
static volatile int ofl_lock[1];

FILE **__ofl_lock()
{
	LOCK(ofl_lock);
	return &ofl_head;
}

void __ofl_unlock()
{
	UNLOCK(ofl_lock);
}
