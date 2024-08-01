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
#ifndef _ASM_RISCV_HWCAP_H
#define _ASM_RISCV_HWCAP_H
#define COMPAT_HWCAP_ISA_I (1 << ('I' - 'A'))
#define COMPAT_HWCAP_ISA_M (1 << ('M' - 'A'))
#define COMPAT_HWCAP_ISA_A (1 << ('A' - 'A'))
#define COMPAT_HWCAP_ISA_F (1 << ('F' - 'A'))
#define COMPAT_HWCAP_ISA_D (1 << ('D' - 'A'))
#define COMPAT_HWCAP_ISA_C (1 << ('C' - 'A'))
#endif