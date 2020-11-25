#define _BSD_SOURCE
#include <stdlib.h>

void *memalign(size_t align, size_t len)
{
	return aligned_alloc(align, len);
}
