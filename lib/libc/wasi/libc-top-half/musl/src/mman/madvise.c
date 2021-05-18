#include <sys/mman.h>
#include "syscall.h"

int __madvise(void *addr, size_t len, int advice)
{
	return syscall(SYS_madvise, addr, len, advice);
}

weak_alias(__madvise, madvise);
