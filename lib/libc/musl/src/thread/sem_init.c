#include <semaphore.h>
#include <limits.h>
#include <errno.h>

int sem_init(sem_t *sem, int pshared, unsigned value)
{
	if (value > SEM_VALUE_MAX) {
		errno = EINVAL;
		return -1;
	}
	sem->__val[0] = value;
	sem->__val[1] = 0;
	sem->__val[2] = pshared ? 0 : 128;
	return 0;
}
