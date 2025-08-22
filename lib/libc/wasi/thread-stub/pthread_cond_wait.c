#include "pthread_impl.h"

int pthread_cond_wait(pthread_cond_t *restrict c, pthread_mutex_t *restrict m)
{
	/* Because there is no other thread that can signal us, this is a deadlock immediately.
	The other possible choice is to return immediately (spurious wakeup), but that is likely to
	just result in the program spinning forever on a condition that cannot become true. */
	__builtin_trap();
}
