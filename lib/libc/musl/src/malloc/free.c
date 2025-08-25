#include <stdlib.h>

void free(void *p)
{
	__libc_free(p);
}
