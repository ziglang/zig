#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include "syscall.h"
#include "kstat.h"

int fchmodat(int fd, const char *path, mode_t mode, int flag)
{
	if (!flag) return syscall(SYS_fchmodat, fd, path, mode, flag);

	if (flag != AT_SYMLINK_NOFOLLOW)
		return __syscall_ret(-EINVAL);

	struct kstat st;
	int ret, fd2;
	char proc[15+3*sizeof(int)];

	if ((ret = __syscall(SYS_fstatat, fd, path, &st, flag)))
		return __syscall_ret(ret);
	if (S_ISLNK(st.st_mode))
		return __syscall_ret(-EOPNOTSUPP);

	if ((fd2 = __syscall(SYS_openat, fd, path, O_RDONLY|O_PATH|O_NOFOLLOW|O_NOCTTY|O_CLOEXEC)) < 0) {
		if (fd2 == -ELOOP)
			return __syscall_ret(-EOPNOTSUPP);
		return __syscall_ret(fd2);
	}

	__procfdname(proc, fd2);
	ret = __syscall(SYS_fstatat, AT_FDCWD, proc, &st, 0);
	if (!ret) {
		if (S_ISLNK(st.st_mode)) ret = -EOPNOTSUPP;
		else ret = __syscall(SYS_fchmodat, AT_FDCWD, proc, mode);
	}

	__syscall(SYS_close, fd2);
	return __syscall_ret(ret);
}
