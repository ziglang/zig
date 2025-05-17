/*	$NetBSD: linux32_machdep.h,v 1.3 2013/11/18 01:32:52 chs Exp $ */

#ifndef _MACHINE_LINUX32_H_
#define _MACHINE_LINUX32_H_

#include <compat/netbsd32/netbsd32.h>

#include <compat/linux/common/linux_types.h>
#include <compat/linux32/common/linux32_types.h>

#include <compat/linux32/arch/amd64/linux32_siginfo.h>
#include <compat/linux32/arch/amd64/linux32_signal.h>
#include <compat/linux32/arch/amd64/linux32_syscallargs.h>
#include <compat/linux32/arch/amd64/linux32_syscall.h>
#include <compat/linux32/arch/amd64/linux32_machdep.h>

#endif /* _MACHINE_LINUX32_H_ */