#include <sys/fsuid.h>
#include "syscall.h"

int setfsgid(gid_t gid)
{
	return syscall(SYS_setfsgid, gid);
}
