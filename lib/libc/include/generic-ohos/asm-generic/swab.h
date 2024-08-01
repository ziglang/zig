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
#ifndef _ASM_GENERIC_SWAB_H
#define _ASM_GENERIC_SWAB_H
#include <asm/bitsperlong.h>
#if __BITS_PER_LONG == 32
#if defined(__GNUC__) && !defined(__STRICT_ANSI__)
#define __SWAB_64_THRU_32__
#endif
#endif
#endif