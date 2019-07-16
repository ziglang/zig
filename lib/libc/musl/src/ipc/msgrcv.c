#include <sys/msg.h>
#include "syscall.h"
#include "ipc.h"

ssize_t msgrcv(int q, void *m, size_t len, long type, int flag)
{
#ifdef SYS_msgrcv
	return syscall_cp(SYS_msgrcv, q, m, len, type, flag);
#else
	return syscall_cp(SYS_ipc, IPCOP_msgrcv, q, len, flag, ((long[]){ (long)m, type }));
#endif
}
