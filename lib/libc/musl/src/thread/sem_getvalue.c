#include <semaphore.h>
#include <limits.h>

int sem_getvalue(sem_t *restrict sem, int *restrict valp)
{
	int val = sem->__val[0];
	*valp = val & SEM_VALUE_MAX;
	return 0;
}
