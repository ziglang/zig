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
#ifndef _ASM_SWAB_H
#define _ASM_SWAB_H
#include <linux/types.h>
#define __SWAB_64_THRU_32__
#if !defined(__mips16) && (defined(__mips_isa_rev) && __mips_isa_rev >= 2 || defined(_MIPS_ARCH_LOONGSON3A))
#define __arch_swab16 __arch_swab16
#define __arch_swab32 __arch_swab32
#ifdef __mips64
#define __arch_swab64 __arch_swab64
#endif
#endif
#endif