#include <unistd.h>
#include "syscall.h"

off_t __lseek(int fd, off_t offset, int whence)
{
	off_t ret;
	__asm__ __volatile__ ("syscall"
		: "=a"(ret)
		: "a"(SYS_lseek), "D"(fd), "S"(offset), "d"(whence)
		: "rcx", "r11", "memory");
	return ret < 0 ? __syscall_ret(ret) : ret;
}

weak_alias(__lseek, lseek);
