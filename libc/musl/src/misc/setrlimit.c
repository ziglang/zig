#include <sys/resource.h>
#include <errno.h>
#include "syscall.h"
#include "libc.h"

#define MIN(a, b) ((a)<(b) ? (a) : (b))
#define FIX(x) do{ if ((x)>=SYSCALL_RLIM_INFINITY) (x)=RLIM_INFINITY; }while(0)

static int __setrlimit(int resource, const struct rlimit *rlim)
{
	unsigned long k_rlim[2];
	struct rlimit tmp;
	if (SYSCALL_RLIM_INFINITY != RLIM_INFINITY) {
		tmp = *rlim;
		FIX(tmp.rlim_cur);
		FIX(tmp.rlim_max);
		rlim = &tmp;
	}
	int ret = __syscall(SYS_prlimit64, 0, resource, rlim, 0);
	if (ret != -ENOSYS) return ret;
	k_rlim[0] = MIN(rlim->rlim_cur, MIN(-1UL, SYSCALL_RLIM_INFINITY));
	k_rlim[1] = MIN(rlim->rlim_max, MIN(-1UL, SYSCALL_RLIM_INFINITY));
	return __syscall(SYS_setrlimit, resource, k_rlim);
}

struct ctx {
	const struct rlimit *rlim;
	int res;
	int err;
};

static void do_setrlimit(void *p)
{
	struct ctx *c = p;
	if (c->err>0) return;
	c->err = -__setrlimit(c->res, c->rlim);
}

int setrlimit(int resource, const struct rlimit *rlim)
{
	struct ctx c = { .res = resource, .rlim = rlim, .err = -1 };
	__synccall(do_setrlimit, &c);
	if (c.err) {
		if (c.err>0) errno = c.err;
		return -1;
	}
	return 0;
}

weak_alias(setrlimit, setrlimit64);
