#include <sys/fsuid.h>
#include "syscall.h"

int setfsuid(uid_t uid)
{
	return syscall(SYS_setfsuid, uid);
}
