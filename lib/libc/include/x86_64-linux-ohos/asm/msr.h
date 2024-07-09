/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _UAPI_ASM_X86_MSR_H
#define _UAPI_ASM_X86_MSR_H
#ifndef __ASSEMBLY__
#include <linux/types.h>
#include <linux/ioctl.h>
#define X86_IOC_RDMSR_REGS _IOWR('c', 0xA0, __u32[8])
#define X86_IOC_WRMSR_REGS _IOWR('c', 0xA1, __u32[8])
#endif
#endif
