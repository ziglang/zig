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
#ifndef SYS_ipc
	int r = __syscall(SYS_shmctl, id, IPC_CMD(cmd), buf);
#else
	int r = __syscall(SYS_ipc, IPCOP_shmctl, id, IPC_CMD(cmd), 0, buf, 0);
#endif
#ifdef SYSCALL_IPC_BROKEN_MODE
	if (r >= 0) switch (cmd | IPC_TIME64) {
	case IPC_STAT:
	case SHM_STAT:
	case SHM_STAT_ANY:
		buf->shm_perm.mode >>= 16;
	}
#endif
#if IPC_TIME64
	if (r >= 0 && (cmd&IPC_TIME64)) {
		IPC_HILO(buf, shm_atime);
		IPC_HILO(buf, shm_dtime);
		IPC_HILO(buf, shm_ctime);
	}
#endif
	return __syscall_ret(r);
}
