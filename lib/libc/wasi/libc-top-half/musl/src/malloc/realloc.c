#include <stdlib.h>

void *realloc(void *p, size_t n)
{
	return __libc_realloc(p, n);
}
