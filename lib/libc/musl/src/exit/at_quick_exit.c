#include <stdlib.h>
#include "libc.h"
#include "lock.h"

#define COUNT 32

static void (*funcs[COUNT])(void);
static int count;
static volatile int lock[1];

void __funcs_on_quick_exit()
{
	void (*func)(void);
	LOCK(lock);
	while (count > 0) {
		func = funcs[--count];
		UNLOCK(lock);
		func();
		LOCK(lock);
	}
}

int at_quick_exit(void (*func)(void))
{
	int r = 0;
	LOCK(lock);
	if (count == 32) r = -1;
	else funcs[count++] = func;
	UNLOCK(lock);
	return r;
}
