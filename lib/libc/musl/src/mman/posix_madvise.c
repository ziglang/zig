#define _GNU_SOURCE
#include <sys/mman.h>
#include "syscall.h"

int posix_madvise(void *addr, size_t len, int advice)
{
	if (advice == MADV_DONTNEED) return 0;
	return -__syscall(SYS_madvise, addr, len, advice);
}
