#include "time32.h"
#include <time.h>
#include <semaphore.h>

int __sem_timedwait_time32(sem_t *sem, const struct timespec32 *restrict ts32)
{
	return sem_timedwait(sem, !ts32 ? 0 : (&(struct timespec){
		.tv_sec = ts32->tv_sec, .tv_nsec = ts32->tv_nsec}));
}
