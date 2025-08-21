#include "pthread_impl.h"

#ifndef __wasilibc_unmodified_upstream
#include <common/clock.h>
#endif

int pthread_condattr_setclock(pthread_condattr_t *a, clockid_t clk)
{
#ifdef __wasilibc_unmodified_upstream
	if (clk < 0 || clk-2U < 2) return EINVAL;
#else
	if (clk->id < 0 || clk->id-2U < 2) return EINVAL;
#endif
	a->__attr &= 0x80000000;
#ifdef __wasilibc_unmodified_upstream
	a->__attr |= clk;
#else
	a->__attr |= clk->id;
#endif
	return 0;
}
