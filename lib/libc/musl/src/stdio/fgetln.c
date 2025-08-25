#define _GNU_SOURCE
#include "stdio_impl.h"
#include <string.h>

char *fgetln(FILE *f, size_t *plen)
{
	char *ret = 0, *z;
	ssize_t l;
	FLOCK(f);
	ungetc(getc_unlocked(f), f);
	if (f->rend && (z=memchr(f->rpos, '\n', f->rend - f->rpos))) {
		ret = (char *)f->rpos;
		*plen = ++z - ret;
		f->rpos = (void *)z;
	} else if ((l = getline(&f->getln_buf, (size_t[]){0}, f)) > 0) {
		*plen = l;
		ret = f->getln_buf;
	}
	FUNLOCK(f);
	return ret;
}
