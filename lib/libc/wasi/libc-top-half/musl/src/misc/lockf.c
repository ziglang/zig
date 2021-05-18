#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

int lockf(int fd, int op, off_t size)
{
	struct flock l = {
		.l_type = F_WRLCK,
		.l_whence = SEEK_CUR,
		.l_len = size,
	};
	switch (op) {
	case F_TEST:
		l.l_type = F_RDLCK;
		if (fcntl(fd, F_GETLK, &l) < 0)
			return -1;
		if (l.l_type == F_UNLCK || l.l_pid == getpid())
			return 0;
		errno = EACCES;
		return -1;
	case F_ULOCK:
		l.l_type = F_UNLCK;
	case F_TLOCK:
		return fcntl(fd, F_SETLK, &l);
	case F_LOCK:
		return fcntl(fd, F_SETLKW, &l);
	}
	errno = EINVAL;
	return -1;
}

weak_alias(lockf, lockf64);
