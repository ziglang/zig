#define _GNU_SOURCE
#include <unistd.h>
#include <signal.h>
#include "syscall.h"
#include "libc.h"

struct ctx {
	size_t count;
	const gid_t *list;
	int ret;
};

static void do_setgroups(void *p)
{
	struct ctx *c = p;
	if (c->ret<0) return;
	int ret = __syscall(SYS_setgroups, c->count, c->list);
	if (ret && !c->ret) {
		/* If one thread fails to set groups after another has already
		 * succeeded, forcibly killing the process is the only safe
		 * thing to do. State is inconsistent and dangerous. Use
		 * SIGKILL because it is uncatchable. */
		__block_all_sigs(0);
		__syscall(SYS_kill, __syscall(SYS_getpid), SIGKILL);
	}
	c->ret = ret;
}

int setgroups(size_t count, const gid_t list[])
{
	/* ret is initially nonzero so that failure of the first thread does not
	 * trigger the safety kill above. */
	struct ctx c = { .count = count, .list = list, .ret = 1 };
	__synccall(do_setgroups, &c);
	return __syscall_ret(c.ret);
}
