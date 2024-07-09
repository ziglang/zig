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
#ifndef _ASM_X86_UCONTEXT_H
#define _ASM_X86_UCONTEXT_H
#define UC_FP_XSTATE 0x1
#ifdef __x86_64__
#define UC_SIGCONTEXT_SS 0x2
#define UC_STRICT_RESTORE_SS 0x4
#endif
#include <asm-generic/ucontext.h>
#endif
