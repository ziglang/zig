#include "pthread_impl.h"
#include "libc.h"

void __pthread_key_delete_synccall(void (*f)(void *), void *p)
{
	__synccall(f, p);
}

int __pthread_key_delete(pthread_key_t k)
{
	return __pthread_key_delete_impl(k);
}

weak_alias(__pthread_key_delete, pthread_key_delete);
