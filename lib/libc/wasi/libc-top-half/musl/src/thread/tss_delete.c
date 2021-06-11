#include <threads.h>
#include <pthread.h>

void tss_delete(tss_t key)
{
	__pthread_key_delete(key);
}
