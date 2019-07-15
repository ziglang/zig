#include <unistd.h>
#include "syscall.h"
#include "libc.h"

int seteuid(uid_t euid)
{
	return __setxid(SYS_setresuid, -1, euid, -1);
}
