#include <stddef.h>
#include "pthread_impl.h"

void *__tls_get_addr(tls_mod_off_t *v)
{
	pthread_t self = __pthread_self();
	if (v[0] <= self->dtv[0])
		return (void *)(self->dtv[v[0]] + v[1]);
	return __tls_get_new(v);
}

weak_alias(__tls_get_addr, __tls_get_new);
