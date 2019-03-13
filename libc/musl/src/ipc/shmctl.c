#include <sys/shm.h>
#include <endian.h>
#include "syscall.h"
#include "ipc.h"

#if __BYTE_ORDER != __BIG_ENDIAN
#undef SYSCALL_IPC_BROKEN_MODE
#endif

int shmctl(int id, int cmd, struct shmid_ds *buf)
{
#ifdef SYSCALL_IPC_BROKEN_MODE
	struct shmid_ds tmp;
	if (cmd == IPC_SET) {
		tmp = *buf;
		tmp.shm_perm.mode *= 0x10000U;
		buf = &tmp;
	}
#endif
#ifdef SYS_shmctl
	int r = __syscall(SYS_shmctl, id, cmd | IPC_64, buf);
#else
	int r = __syscall(SYS_ipc, IPCOP_shmctl, id, cmd | IPC_64, 0, buf, 0);
#endif
#ifdef SYSCALL_IPC_BROKEN_MODE
	if (r >= 0) switch (cmd) {
	case IPC_STAT:
	case SHM_STAT:
	case SHM_STAT_ANY:
		buf->shm_perm.mode >>= 16;
	}
#endif
	return __syscall_ret(r);
}
