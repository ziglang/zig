#include <unistd.h>
#include <fcntl.h>
#include "syscall.h"

int lchown(const char *path, uid_t uid, gid_t gid)
{
#ifdef SYS_lchown
	return syscall(SYS_lchown, path, uid, gid);
#else
	return syscall(SYS_fchownat, AT_FDCWD, path, uid, gid, AT_SYMLINK_NOFOLLOW);
#endif
}
