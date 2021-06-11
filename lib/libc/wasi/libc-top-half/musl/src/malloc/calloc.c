#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include "dynlink.h"

static size_t mal0_clear(char *p, size_t n)
{
	const size_t pagesz = 4096; /* arbitrary */
	if (n < pagesz) return n;
#ifdef __GNUC__
	typedef uint64_t __attribute__((__may_alias__)) T;
#else
	typedef unsigned char T;
#endif
	char *pp = p + n;
	size_t i = (uintptr_t)pp & (pagesz - 1);
	for (;;) {
		pp = memset(pp - i, 0, i);
		if (pp - p < pagesz) return pp - p;
		for (i = pagesz; i; i -= 2*sizeof(T), pp -= 2*sizeof(T))
		        if (((T *)pp)[-1] | ((T *)pp)[-2])
				break;
	}
}

static int allzerop(void *p)
{
	return 0;
}
weak_alias(allzerop, __malloc_allzerop);

void *calloc(size_t m, size_t n)
{
	if (n && m > (size_t)-1/n) {
		errno = ENOMEM;
		return 0;
	}
	n *= m;
	void *p = malloc(n);
	if (!p || (!__malloc_replaced && __malloc_allzerop(p)))
		return p;
	n = mal0_clear(p, n);
	return memset(p, 0, n);
}
