#include <sys/stat.h>

#if !_REDIR_TIME64

int __fxstat(int ver, int fd, struct stat *buf)
{
	return fstat(fd, buf);
}

int __fxstatat(int ver, int fd, const char *path, struct stat *buf, int flag)
{
	return fstatat(fd, path, buf, flag);
}

int __lxstat(int ver, const char *path, struct stat *buf)
{
	return lstat(path, buf);
}

int __xstat(int ver, const char *path, struct stat *buf)
{
	return stat(path, buf);
}

#endif

int __xmknod(int ver, const char *path, mode_t mode, dev_t *dev)
{
	return mknod(path, mode, *dev);
}

int __xmknodat(int ver, int fd, const char *path, mode_t mode, dev_t *dev)
{
	return mknodat(fd, path, mode, *dev);
}
