#include <threads.h>

int cnd_wait(cnd_t *c, mtx_t *m)
{
	/* Calling cnd_timedwait with a null pointer is an extension.
	 * It is convenient here to avoid duplication of the logic
	 * for return values. */
	return cnd_timedwait(c, m, 0);
}
