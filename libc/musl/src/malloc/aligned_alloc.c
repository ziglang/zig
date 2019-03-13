#include <stdlib.h>
#include "malloc_impl.h"

void *aligned_alloc(size_t align, size_t len)
{
	return __memalign(align, len);
}
