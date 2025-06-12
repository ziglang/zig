/* $NetBSD: signal.h,v 1.4 2021/11/05 15:18:18 thorpej Exp $ */

#ifndef _AARCH64_SIGNAL_H_
#define	_AARCH64_SIGNAL_H_

#include <arm/signal.h>

#ifdef _KERNEL
/*
 * Normally, to support COMPAT_NETBSD32 we need to define
 * __HAVE_STRUCT_SIGCONTEXT in order to support the old
 * "sigcontext" style of handlers for 32-bit binaries.
 * However, we only support 32-bit EABI binaries on AArch64,
 * and by happy accident (due to a libc bug introduced in
 * 2006), 32-bit NetBSD EABI binaries never used "sigcontext"
 * style handlers.  So, we don't need to carry any of this
 * baggage forward.
 */
#endif /* _KERNEL */

#endif /* ! _AARCH64_SIGNAL_H_ */