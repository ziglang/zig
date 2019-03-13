#include <stdlib.h>
#include <limits.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include "syscall.h"

char *realpath(const char *restrict filename, char *restrict resolved)
{
	int fd;
	ssize_t r;
	struct stat st1, st2;
	char buf[15+3*sizeof(int)];
	char tmp[PATH_MAX];

	if (!filename) {
		errno = EINVAL;
		return 0;
	}

	fd = sys_open(filename, O_PATH|O_NONBLOCK|O_CLOEXEC);
	if (fd < 0) return 0;
	__procfdname(buf, fd);

	r = readlink(buf, tmp, sizeof tmp - 1);
	if (r < 0) goto err;
	tmp[r] = 0;

	fstat(fd, &st1);
	r = stat(tmp, &st2);
	if (r<0 || st1.st_dev != st2.st_dev || st1.st_ino != st2.st_ino) {
		if (!r) errno = ELOOP;
		goto err;
	}

	__syscall(SYS_close, fd);
	return resolved ? strcpy(resolved, tmp) : strdup(tmp);
err:
	__syscall(SYS_close, fd);
	return 0;
}
