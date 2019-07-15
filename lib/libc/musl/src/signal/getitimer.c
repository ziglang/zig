#include <sys/time.h>
#include "syscall.h"

int getitimer(int which, struct itimerval *old)
{
	return syscall(SYS_getitimer, which, old);
}
