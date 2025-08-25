#include <sys/random.h>
#include "syscall.h"

ssize_t getrandom(void *buf, size_t buflen, unsigned flags)
{
	return syscall_cp(SYS_getrandom, buf, buflen, flags);
}
