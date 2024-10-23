#include <unistd.h>
#include <signal.h>
#include "syscall.h"
#include "libc.h"

struct ctx {
	int id, eid, sid;
	int nr, ret;
};

static void do_setxid(void *p)
{
	struct ctx *c = p;
	if (c->ret<0) return;
	int ret = __syscall(c->nr, c->id, c->eid, c->sid);
	if (ret && !c->ret) {
		/* If one thread fails to set ids after another has already
		 * succeeded, forcibly killing the process is the only safe
		 * thing to do. State is inconsistent and dangerous. Use
		 * SIGKILL because it is uncatchable. */
		__block_all_sigs(0);
		__syscall(SYS_kill, __syscall(SYS_getpid), SIGKILL);
	}
	c->ret = ret;
}

int __setxid(int nr, int id, int eid, int sid)
{
	/* ret is initially nonzero so that failure of the first thread does not
	 * trigger the safety kill above. */
	struct ctx c = { .nr = nr, .id = id, .eid = eid, .sid = sid, .ret = 1 };
	__synccall(do_setxid, &c);
	return __syscall_ret(c.ret > 0 ? -EAGAIN : c.ret);
}
