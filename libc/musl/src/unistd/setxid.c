#include <unistd.h>
#include <errno.h>
#include "syscall.h"
#include "libc.h"
#include "pthread_impl.h"

struct ctx {
	int id, eid, sid;
	int nr, err;
};

static void do_setxid(void *p)
{
	struct ctx *c = p;
	if (c->err>0) return;
	int ret = -__syscall(c->nr, c->id, c->eid, c->sid);
	if (ret && !c->err) {
		/* If one thread fails to set ids after another has already
		 * succeeded, forcibly killing the process is the only safe
		 * thing to do. State is inconsistent and dangerous. Use
		 * SIGKILL because it is uncatchable. */
		__block_all_sigs(0);
		__syscall(SYS_kill, __syscall(SYS_getpid), SIGKILL);
	}
	c->err = ret;
}

int __setxid(int nr, int id, int eid, int sid)
{
	/* err is initially nonzero so that failure of the first thread does not
	 * trigger the safety kill above. */
	struct ctx c = { .nr = nr, .id = id, .eid = eid, .sid = sid, .err = -1 };
	__synccall(do_setxid, &c);
	if (c.err) {
		if (c.err>0) errno = c.err;
		return -1;
	}
	return 0;
}
