#include <sys/msg.h>
#include <endian.h>
#include "syscall.h"
#include "ipc.h"

#if __BYTE_ORDER != __BIG_ENDIAN
#undef SYSCALL_IPC_BROKEN_MODE
#endif

int msgctl(int q, int cmd, struct msqid_ds *buf)
{
#if IPC_TIME64
	struct msqid_ds out, *orig;
	if (cmd&IPC_TIME64) {
		out = (struct msqid_ds){0};
		orig = buf;
		buf = &out;
	}
#endif
#ifdef SYSCALL_IPC_BROKEN_MODE
	struct msqid_ds tmp;
	if (cmd == IPC_SET) {
		tmp = *buf;
		tmp.msg_perm.mode *= 0x10000U;
		buf = &tmp;
	}
#endif
#ifndef SYS_ipc
	int r = __syscall(SYS_msgctl, q, IPC_CMD(cmd), buf);
#else
	int r = __syscall(SYS_ipc, IPCOP_msgctl, q, IPC_CMD(cmd), 0, buf, 0);
#endif
#ifdef SYSCALL_IPC_BROKEN_MODE
	if (r >= 0) switch (cmd | IPC_TIME64) {
	case IPC_STAT:
	case MSG_STAT:
	case MSG_STAT_ANY:
		buf->msg_perm.mode >>= 16;
	}
#endif
#if IPC_TIME64
	if (r >= 0 && (cmd&IPC_TIME64)) {
		buf = orig;
		*buf = out;
		IPC_HILO(buf, msg_stime);
		IPC_HILO(buf, msg_rtime);
		IPC_HILO(buf, msg_ctime);
	}
#endif
	return __syscall_ret(r);
}
