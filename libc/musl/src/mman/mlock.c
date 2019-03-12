#include <sys/mman.h>
#include "syscall.h"

int mlock(const void *addr, size_t len)
{
	return syscall(SYS_mlock, addr, len);
}
