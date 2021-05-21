#define _GNU_SOURCE
#include <sys/stat.h>
#include <sys/time.h>
#include <fcntl.h>

int lutimes(const char *filename, const struct timeval tv[2])
{
	struct timespec times[2];
	if (tv) {
		times[0].tv_sec  = tv[0].tv_sec;
		times[0].tv_nsec = tv[0].tv_usec * 1000;
		times[1].tv_sec  = tv[1].tv_sec;
		times[1].tv_nsec = tv[1].tv_usec * 1000;
	}
	return utimensat(AT_FDCWD, filename, tv ? times : 0, AT_SYMLINK_NOFOLLOW);
}
