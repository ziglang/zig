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
#ifndef __ASM_X86_BITSPERLONG_H
#define __ASM_X86_BITSPERLONG_H
#if defined(__x86_64__) && !defined(__ILP32__)
#define __BITS_PER_LONG 64
#else
#define __BITS_PER_LONG 32
#endif
#include <asm-generic/bitsperlong.h>
#endif
