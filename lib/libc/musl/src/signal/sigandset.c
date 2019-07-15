#define _GNU_SOURCE
#include <signal.h>

#define SST_SIZE (_NSIG/8/sizeof(long))

int sigandset(sigset_t *dest, const sigset_t *left, const sigset_t *right)
{
	unsigned long i = 0, *d = (void*) dest, *l = (void*) left, *r = (void*) right;
	for(; i < SST_SIZE; i++) d[i] = l[i] & r[i];
	return 0;
}

