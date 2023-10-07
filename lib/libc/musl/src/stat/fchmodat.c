#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include "syscall.h"

int fchmodat(int fd, const char *path, mode_t mode, int flag)
{
	if (!flag) return syscall(SYS_fchmodat, fd, path, mode, flag);

	if (flag != AT_SYMLINK_NOFOLLOW)
		return __syscall_ret(-EINVAL);

	struct stat st;
	int ret, fd2;
	char proc[15+3*sizeof(int)];

	if (fstatat(fd, path, &st, flag))
		return -1;
	if (S_ISLNK(st.st_mode))
		return __syscall_ret(-EOPNOTSUPP);

	if ((fd2 = __syscall(SYS_openat, fd, path, O_RDONLY|O_PATH|O_NOFOLLOW|O_NOCTTY|O_CLOEXEC)) < 0) {
		if (fd2 == -ELOOP)
			return __syscall_ret(-EOPNOTSUPP);
		return __syscall_ret(fd2);
	}

	__procfdname(proc, fd2);
	ret = stat(proc, &st);
	if (!ret) {
		if (S_ISLNK(st.st_mode)) ret = __syscall_ret(-EOPNOTSUPP);
		else ret = syscall(SYS_fchmodat, AT_FDCWD, proc, mode);
	}

	__syscall(SYS_close, fd2);
	return ret;
}
