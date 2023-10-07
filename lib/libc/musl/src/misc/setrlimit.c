#include <sys/resource.h>
#include <errno.h>
#include "syscall.h"
#include "libc.h"

#define MIN(a, b) ((a)<(b) ? (a) : (b))
#define FIX(x) do{ if ((x)>=SYSCALL_RLIM_INFINITY) (x)=RLIM_INFINITY; }while(0)

struct ctx {
	unsigned long lim[2];
	int res;
	int err;
};

#ifdef SYS_setrlimit
static void do_setrlimit(void *p)
{
	struct ctx *c = p;
	if (c->err>0) return;
	c->err = -__syscall(SYS_setrlimit, c->res, c->lim);
}
#endif

int setrlimit(int resource, const struct rlimit *rlim)
{
	struct rlimit tmp;
	if (SYSCALL_RLIM_INFINITY != RLIM_INFINITY) {
		tmp = *rlim;
		FIX(tmp.rlim_cur);
		FIX(tmp.rlim_max);
		rlim = &tmp;
	}
	int ret = __syscall(SYS_prlimit64, 0, resource, rlim, 0);
#ifdef SYS_setrlimit
	if (ret != -ENOSYS) return __syscall_ret(ret);

	struct ctx c = {
		.lim[0] = MIN(rlim->rlim_cur, MIN(-1UL, SYSCALL_RLIM_INFINITY)),
		.lim[1] = MIN(rlim->rlim_max, MIN(-1UL, SYSCALL_RLIM_INFINITY)),
		.res = resource, .err = -1
	};
	__synccall(do_setrlimit, &c);
	if (c.err) {
		if (c.err>0) errno = c.err;
		return -1;
	}
	return 0;
#else
	return __syscall_ret(ret);
#endif
}
