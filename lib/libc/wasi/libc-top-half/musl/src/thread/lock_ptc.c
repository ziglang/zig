#include <pthread.h>

static pthread_rwlock_t lock = PTHREAD_RWLOCK_INITIALIZER;

void __inhibit_ptc()
{
	pthread_rwlock_wrlock(&lock);
}

void __acquire_ptc()
{
	pthread_rwlock_rdlock(&lock);
}

void __release_ptc()
{
	pthread_rwlock_unlock(&lock);
}
