#include <sys/msg.h>
#include "syscall.h"
#include "ipc.h"

int msgget(key_t k, int flag)
{
#ifdef SYS_msgget
	return syscall(SYS_msgget, k, flag);
#else
	return syscall(SYS_ipc, IPCOP_msgget, k, flag);
#endif
}
