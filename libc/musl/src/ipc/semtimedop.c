#define _GNU_SOURCE
#include <sys/sem.h>
#include "syscall.h"
#include "ipc.h"

int semtimedop(int id, struct sembuf *buf, size_t n, const struct timespec *ts)
{
#ifdef SYS_semtimedop
	return syscall(SYS_semtimedop, id, buf, n, ts);
#else
	return syscall(SYS_ipc, IPCOP_semtimedop, id, n, 0, buf, ts);
#endif
}
