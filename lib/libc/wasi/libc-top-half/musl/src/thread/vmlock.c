#include "pthread_impl.h"
#include "fork_impl.h"

static volatile int vmlock[2];
volatile int *const __vmlock_lockptr = vmlock;

void __vm_wait()
{
	int tmp;
	while ((tmp=vmlock[0]))
		__wait(vmlock, vmlock+1, tmp, 1);
}

void __vm_lock()
{
	a_inc(vmlock);
}

void __vm_unlock()
{
	if (a_fetch_add(vmlock, -1)==1 && vmlock[1])
		__wake(vmlock, -1, 1);
}
