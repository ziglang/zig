#include <unistd.h>
#include "syscall.h"

gid_t getegid(void)
{
	return __syscall(SYS_getegid);
}
