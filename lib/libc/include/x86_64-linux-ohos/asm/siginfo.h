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
#ifndef _ASM_X86_SIGINFO_H
#define _ASM_X86_SIGINFO_H
#ifdef __x86_64__
#ifdef __ILP32__
typedef long long __kernel_si_clock_t __attribute__((aligned(4)));
#define __ARCH_SI_CLOCK_T __kernel_si_clock_t
#define __ARCH_SI_ATTRIBUTES __attribute__((aligned(8)))
#endif
#endif
#include <asm-generic/siginfo.h>
#endif
