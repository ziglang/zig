#define _BSD_SOURCE
#include <errno.h>
#include <stdlib.h>

void *reallocarray(void *ptr, size_t m, size_t n)
{
	if (n && m > -1 / n) {
		errno = ENOMEM;
		return 0;
	}

	return realloc(ptr, m * n);
}
