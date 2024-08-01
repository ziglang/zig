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
#ifndef _UAPI_LINUX_KERNEL_H
#define _UAPI_LINUX_KERNEL_H
#include <linux/sysinfo.h>
#define __ALIGN_KERNEL(x,a) __ALIGN_KERNEL_MASK(x, (typeof(x)) (a) - 1)
#define __ALIGN_KERNEL_MASK(x,mask) (((x) + (mask)) & ~(mask))
#define __KERNEL_DIV_ROUND_UP(n,d) (((n) + (d) - 1) / (d))
#endif