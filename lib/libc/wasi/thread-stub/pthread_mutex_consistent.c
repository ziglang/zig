#include "pthread_impl.h"

int pthread_mutex_consistent(pthread_mutex_t *m)
{
	/* cannot be a robust mutex, as they're entirely unsupported in WASI */
	return EINVAL;

}
