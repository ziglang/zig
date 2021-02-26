#include <stdlib.h>

void free(void *p)
{
	return __libc_free(p);
}
