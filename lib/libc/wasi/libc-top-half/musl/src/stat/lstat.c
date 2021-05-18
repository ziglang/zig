#include <sys/stat.h>
#include <fcntl.h>

int lstat(const char *restrict path, struct stat *restrict buf)
{
	return fstatat(AT_FDCWD, path, buf, AT_SYMLINK_NOFOLLOW);
}

#if !_REDIR_TIME64
weak_alias(lstat, lstat64);
#endif
