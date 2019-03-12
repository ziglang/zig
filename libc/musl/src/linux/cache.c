#include "syscall.h"

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
