#include <sys/shm.h>
#include <stdint.h>
#include "syscall.h"
#include "ipc.h"

int shmget(key_t key, size_t size, int flag)
{
	if (size > PTRDIFF_MAX) size = SIZE_MAX;
#ifndef SYS_ipc
	return syscall(SYS_shmget, key, size, flag);
#else
	return syscall(SYS_ipc, IPCOP_shmget, key, size, flag);
#endif
}
