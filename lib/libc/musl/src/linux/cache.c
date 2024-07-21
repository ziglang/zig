#include <errno.h>
#include "syscall.h"
#include "atomic.h"

#ifdef SYS_cacheflush
int _flush_cache(void *addr, int len, int op)
{
	return syscall(SYS_cacheflush, addr, len, op);
}
weak_alias(_flush_cache, cacheflush);
#endif

#ifdef SYS_cachectl
int __cachectl(void *addr, int len, int op)
{
	return syscall(SYS_cachectl, addr, len, op);
}
weak_alias(__cachectl, cachectl);
#endif

#ifdef SYS_riscv_flush_icache

#define VDSO_FLUSH_ICACHE_SYM "__vdso_flush_icache"
#define VDSO_FLUSH_ICACHE_VER "LINUX_4.15"

static void *volatile vdso_func;

static int flush_icache_init(void *start, void *end, unsigned long int flags)
{
	void *p = __vdsosym(VDSO_FLUSH_ICACHE_VER, VDSO_FLUSH_ICACHE_SYM);
	int (*f)(void *, void *, unsigned long int) =
		(int (*)(void *, void *, unsigned long int))p;
	a_cas_p(&vdso_func, (void *)flush_icache_init, p);
	return f ? f(start, end, flags) : -ENOSYS;
}

static void *volatile vdso_func = (void *)flush_icache_init;

int __riscv_flush_icache(void *start, void *end, unsigned long int flags) 
{
	int (*f)(void *, void *, unsigned long int) =
		(int (*)(void *, void *, unsigned long int))vdso_func;
	if (f) {
		int r = f(start, end, flags);
		if (!r) return r;
		if (r != -ENOSYS) return __syscall_ret(r);
	}
	return syscall(SYS_riscv_flush_icache, start, end, flags);
}
weak_alias(__riscv_flush_icache, riscv_flush_icache);
#endif
