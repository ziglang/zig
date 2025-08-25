#include "pthread_impl.h"

void *__tls_get_addr(tls_mod_off_t *v)
{
	pthread_t self = __pthread_self();
	return (void *)(self->dtv[v[0]] + v[1]);
}
