/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _ASM_X86_MSR_H
#define _ASM_X86_MSR_H

#ifndef __ASSEMBLY__

#include <linux/types.h>
#include <linux/ioctl.h>

#define X86_IOC_RDMSR_REGS	_IOWR('c', 0xA0, __u32[8])
#define X86_IOC_WRMSR_REGS	_IOWR('c', 0xA1, __u32[8])

#endif /* __ASSEMBLY__ */
#endif /* _ASM_X86_MSR_H */