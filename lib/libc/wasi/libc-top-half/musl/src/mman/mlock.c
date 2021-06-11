#include <sys/mman.h>
#include "syscall.h"

int mlock(const void *addr, size_t len)
{
#ifdef SYS_mlock
	return syscall(SYS_mlock, addr, len);
#else
	return syscall(SYS_mlock2, addr, len, 0);
#endif
}
