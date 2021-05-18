#include <unistd.h>
#include "syscall.h"

gid_t getgid(void)
{
	return __syscall(SYS_getgid);
}
