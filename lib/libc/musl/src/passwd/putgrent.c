#define _GNU_SOURCE
#include <grp.h>
#include <stdio.h>

int putgrent(const struct group *gr, FILE *f)
{
	int r;
	size_t i;
	flockfile(f);
	if ((r = fprintf(f, "%s:%s:%d:", gr->gr_name, gr->gr_passwd, gr->gr_gid))<0) goto done;
	if (gr->gr_mem) for (i=0; gr->gr_mem[i]; i++)
		if ((r = fprintf(f, "%s%s", i?",":"", gr->gr_mem[i]))<0) goto done;
	r = fputc('\n', f);
done:
	funlockfile(f);
	return r<0 ? -1 : 0;
}
