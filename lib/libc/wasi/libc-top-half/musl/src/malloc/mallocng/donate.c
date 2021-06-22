#include <stdlib.h>
#include <stdint.h>
#include <limits.h>
#include <string.h>
#include <sys/mman.h>
#include <errno.h>

#include "meta.h"

static void donate(unsigned char *base, size_t len)
{
	uintptr_t a = (uintptr_t)base;
	uintptr_t b = a + len;
	a += -a & (UNIT-1);
	b -= b & (UNIT-1);
	memset(base, 0, len);
	for (int sc=47; sc>0 && b>a; sc-=4) {
		if (b-a < (size_classes[sc]+1)*UNIT) continue;
		struct meta *m = alloc_meta();
		m->avail_mask = 0;
		m->freed_mask = 1;
		m->mem = (void *)a;
		m->mem->meta = m;
		m->last_idx = 0;
		m->freeable = 0;
		m->sizeclass = sc;
		m->maplen = 0;
		*((unsigned char *)m->mem+UNIT-4) = 0;
		*((unsigned char *)m->mem+UNIT-3) = 255;
		m->mem->storage[size_classes[sc]*UNIT-4] = 0;
		queue(&ctx.active[sc], m);
		a += (size_classes[sc]+1)*UNIT;
	}
}

void __malloc_donate(char *start, char *end)
{
	donate((void *)start, end-start);
}
