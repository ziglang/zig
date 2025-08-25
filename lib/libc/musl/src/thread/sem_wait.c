#include <semaphore.h>

int sem_wait(sem_t *sem)
{
	return sem_timedwait(sem, 0);
}
