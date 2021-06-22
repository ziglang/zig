#include <unistd.h>
#include "syscall.h"

off_t __lseek(int fd, off_t offset, int whence)
{
#ifdef SYS__llseek
	off_t result;
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
	return syscall(SYS__llseek, fd, offset>>32, offset, &result, whence) ? -1 : result;
#else
	return llseek(fd, offset>>32, offset, &result, whence) ? -1 : result;
#endif
#else
#ifdef __wasilibc_unmodified_upstream // WASI has no syscall
	return syscall(SYS_lseek, fd, offset, whence);
#else
	return lseek(fd, offset, whence);
#endif
#endif
}

weak_alias(__lseek, lseek);
weak_alias(__lseek, lseek64);
