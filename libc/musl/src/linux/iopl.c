#include "syscall.h"

#ifdef SYS_iopl
#include <sys/io.h>

int iopl(int level)
{
	return syscall(SYS_iopl, level);
}
#endif
