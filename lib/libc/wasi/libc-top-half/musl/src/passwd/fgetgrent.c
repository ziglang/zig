#define _GNU_SOURCE
#include "pwf.h"

struct group *fgetgrent(FILE *f)
{
	static char *line, **mem;
	static struct group gr;
	struct group *res;
	size_t size=0, nmem=0;
	__getgrent_a(f, &gr, &line, &size, &mem, &nmem, &res);
	return res;
}
