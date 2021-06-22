#include <sys/mman.h>
#include "syscall.h"

int mlockall(int flags)
{
	return syscall(SYS_mlockall, flags);
}
