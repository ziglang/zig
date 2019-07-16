#include <sys/msg.h>
#include <endian.h>
#include "syscall.h"
#include "ipc.h"

#if __BYTE_ORDER != __BIG_ENDIAN
#undef SYSCALL_IPC_BROKEN_MODE
#endif

int msgctl(int q, int cmd, struct msqid_ds *buf)
{
#ifdef SYSCALL_IPC_BROKEN_MODE
	struct msqid_ds tmp;
	if (cmd == IPC_SET) {
		tmp = *buf;
		tmp.msg_perm.mode *= 0x10000U;
		buf = &tmp;
	}
#endif
#ifdef SYS_msgctl
	int r = __syscall(SYS_msgctl, q, cmd | IPC_64, buf);
#else
	int r = __syscall(SYS_ipc, IPCOP_msgctl, q, cmd | IPC_64, 0, buf, 0);
#endif
#ifdef SYSCALL_IPC_BROKEN_MODE
	if (r >= 0) switch (cmd) {
	case IPC_STAT:
	case MSG_STAT:
	case MSG_STAT_ANY:
		buf->msg_perm.mode >>= 16;
	}
#endif
	return __syscall_ret(r);
}
