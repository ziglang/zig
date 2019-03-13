#include <semaphore.h>

int sem_getvalue(sem_t *restrict sem, int *restrict valp)
{
	int val = sem->__val[0];
	*valp = val < 0 ? 0 : val;
	return 0;
}
