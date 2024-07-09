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
#ifndef _UAPI_ASM_TYPES_H
#define _UAPI_ASM_TYPES_H
#include <asm-generic/int-ll64.h>
#ifdef __INT32_TYPE__
#undef __INT32_TYPE__
#define __INT32_TYPE__ int
#endif
#ifdef __UINT32_TYPE__
#undef __UINT32_TYPE__
#define __UINT32_TYPE__ unsigned int
#endif
#ifdef __UINTPTR_TYPE__
#undef __UINTPTR_TYPE__
#define __UINTPTR_TYPE__ unsigned long
#endif
#endif
