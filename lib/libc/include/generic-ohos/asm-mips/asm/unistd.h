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
#ifndef _ASM_UNISTD_H
#define _ASM_UNISTD_H
#include <asm/sgidefs.h>
#if _MIPS_SIM == _MIPS_SIM_ABI32
#define __NR_Linux 4000
#include <asm/unistd_o32.h>
#endif
#if _MIPS_SIM == _MIPS_SIM_ABI64
#define __NR_Linux 5000
#include <asm/unistd_n64.h>
#endif
#if _MIPS_SIM == _MIPS_SIM_NABI32
#define __NR_Linux 6000
#include <asm/unistd_n32.h>
#endif
#endif