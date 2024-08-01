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
#ifndef _UAPI__LINUX_KVM_PARA_H
#define _UAPI__LINUX_KVM_PARA_H
#define KVM_ENOSYS 1000
#define KVM_EFAULT EFAULT
#define KVM_EINVAL EINVAL
#define KVM_E2BIG E2BIG
#define KVM_EPERM EPERM
#define KVM_EOPNOTSUPP 95
#define KVM_HC_VAPIC_POLL_IRQ 1
#define KVM_HC_MMU_OP 2
#define KVM_HC_FEATURES 3
#define KVM_HC_PPC_MAP_MAGIC_PAGE 4
#define KVM_HC_KICK_CPU 5
#define KVM_HC_MIPS_GET_CLOCK_FREQ 6
#define KVM_HC_MIPS_EXIT_VM 7
#define KVM_HC_MIPS_CONSOLE_OUTPUT 8
#define KVM_HC_CLOCK_PAIRING 9
#define KVM_HC_SEND_IPI 10
#define KVM_HC_SCHED_YIELD 11
#include <asm/kvm_para.h>
#endif