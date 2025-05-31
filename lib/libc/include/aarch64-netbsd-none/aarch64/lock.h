/* $NetBSD: lock.h,v 1.5 2022/07/24 20:28:32 riastradh Exp $ */

#ifndef	_AARCH64_LOCK_H_
#define	_AARCH64_LOCK_H_

#include <sys/param.h>

#ifdef __aarch64__
# ifdef _HARDKERNEL
#  ifdef SPINLOCK_BACKOFF_HOOK
#   undef SPINLOCK_BACKOFF_HOOK
#  endif
#  define SPINLOCK_BACKOFF_HOOK		asm volatile("yield" ::: "memory")
# endif
# include <sys/common_lock.h>
#elif defined(__arm__)
# include <arm/lock.h>
#endif

#endif	/* _AARCH64_LOCK_H_ */