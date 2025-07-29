/*       $NetBSD: ptrace.h,v 1.5 2016/10/19 09:44:00 skrll Exp $        */

#include <sparc/ptrace.h>

#ifdef _KERNEL_OPT
#include "opt_compat_netbsd32.h"

#ifdef COMPAT_NETBSD32
#include <compat/netbsd32/netbsd32.h>

#define process_read_regs32	netbsd32_process_read_regs
#define process_read_fpregs32	netbsd32_process_read_fpregs

#define process_write_regs32	netbsd32_process_write_regs
#define process_write_fpregs32	netbsd32_process_write_fpregs

#define process_reg32		struct reg32
#define process_fpreg32		struct fpreg32
#endif
#endif