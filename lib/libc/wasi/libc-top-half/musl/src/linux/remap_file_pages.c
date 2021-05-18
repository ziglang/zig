#define _GNU_SOURCE
#include <sys/mman.h>
#include "syscall.h"

int remap_file_pages(void *addr, size_t size, int prot, size_t pgoff, int flags)
{
	return syscall(SYS_remap_file_pages, addr, size, prot, pgoff, flags);
}
