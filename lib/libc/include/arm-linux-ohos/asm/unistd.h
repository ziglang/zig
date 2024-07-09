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
#ifndef _UAPI__ASM_ARM_UNISTD_H
#define _UAPI__ASM_ARM_UNISTD_H
#define __NR_OABI_SYSCALL_BASE 0x900000
#define __NR_SYSCALL_BASE 0
#include <asm/unistd-eabi.h>
#include <asm/unistd-common.h>
#define __NR_sync_file_range2 __NR_arm_sync_file_range
#define __ARM_NR_BASE (__NR_SYSCALL_BASE + 0x0f0000)
#define __ARM_NR_breakpoint (__ARM_NR_BASE + 1)
#define __ARM_NR_cacheflush (__ARM_NR_BASE + 2)
#define __ARM_NR_usr26 (__ARM_NR_BASE + 3)
#define __ARM_NR_usr32 (__ARM_NR_BASE + 4)
#define __ARM_NR_set_tls (__ARM_NR_BASE + 5)
#define __ARM_NR_get_tls (__ARM_NR_BASE + 6)
#endif
