#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
#include <limits.h>
#include <string.h>
#include <stdlib.h>
#include "syscall.h"

#define MAXTRIES 100

char *tempnam(const char *dir, const char *pfx)
{
	char s[PATH_MAX];
	size_t l, dl, pl;
	int try;
	int r;

	if (!dir) dir = P_tmpdir;
	if (!pfx) pfx = "temp";

	dl = strlen(dir);
	pl = strlen(pfx);
	l = dl + 1 + pl + 1 + 6;

	if (l >= PATH_MAX) {
		errno = ENAMETOOLONG;
		return 0;
	}

	memcpy(s, dir, dl);
	s[dl] = '/';
	memcpy(s+dl+1, pfx, pl);
	s[dl+1+pl] = '_';
	s[l] = 0;

	for (try=0; try<MAXTRIES; try++) {
		__randname(s+l-6);
#ifdef SYS_readlink
		r = __syscall(SYS_readlink, s, (char[1]){0}, 1);
#else
		r = __syscall(SYS_readlinkat, AT_FDCWD, s, (char[1]){0}, 1);
#endif
		if (r == -ENOENT) return strdup(s);
	}
	return 0;
}
