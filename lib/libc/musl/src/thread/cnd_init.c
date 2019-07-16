#include <threads.h>

int cnd_init(cnd_t *c)
{
	*c = (cnd_t){ 0 };
	return thrd_success;
}
