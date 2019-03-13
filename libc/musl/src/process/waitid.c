#include <sys/wait.h>
#include "syscall.h"

int waitid(idtype_t type, id_t id, siginfo_t *info, int options)
{
	return syscall_cp(SYS_waitid, type, id, info, options, 0);
}
