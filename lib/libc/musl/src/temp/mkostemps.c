#define _BSD_SOURCE
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

int __mkostemps(char *template, int len, int flags)
{
	size_t l = strlen(template);
	if (l<6 || len>l-6 || memcmp(template+l-len-6, "XXXXXX", 6)) {
		errno = EINVAL;
		return -1;
	}

	flags -= flags & O_ACCMODE;
	int fd, retries = 100;
	do {
		__randname(template+l-len-6);
		if ((fd = open(template, flags | O_RDWR | O_CREAT | O_EXCL, 0600))>=0)
			return fd;
	} while (--retries && errno == EEXIST);

	memcpy(template+l-len-6, "XXXXXX", 6);
	return -1;
}

weak_alias(__mkostemps, mkostemps);
