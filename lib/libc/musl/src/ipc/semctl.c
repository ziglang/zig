#include <sys/sem.h>
#include <stdarg.h>
#include <endian.h>
#include "syscall.h"
#include "ipc.h"

#if __BYTE_ORDER != __BIG_ENDIAN
#undef SYSCALL_IPC_BROKEN_MODE
#endif

union semun {
	int val;
	struct semid_ds *buf;
	unsigned short *array;
};

int semctl(int id, int num, int cmd, ...)
{
	union semun arg = {0};
	va_list ap;
	switch (cmd) {
	case SETVAL: case GETALL: case SETALL: case IPC_STAT: case IPC_SET:
	case IPC_INFO: case SEM_INFO: case SEM_STAT:
		va_start(ap, cmd);
		arg = va_arg(ap, union semun);
		va_end(ap);
	}
#ifdef SYSCALL_IPC_BROKEN_MODE
	struct semid_ds tmp;
	if (cmd == IPC_SET) {
		tmp = *arg.buf;
		tmp.sem_perm.mode *= 0x10000U;
		arg.buf = &tmp;
	}
#endif
#ifdef SYS_semctl
	int r = __syscall(SYS_semctl, id, num, cmd | IPC_64, arg.buf);
#else
	int r = __syscall(SYS_ipc, IPCOP_semctl, id, num, cmd | IPC_64, &arg.buf);
#endif
#ifdef SYSCALL_IPC_BROKEN_MODE
	if (r >= 0) switch (cmd) {
	case IPC_STAT:
	case SEM_STAT:
	case SEM_STAT_ANY:
		arg.buf->sem_perm.mode >>= 16;
	}
#endif
	return __syscall_ret(r);
}
