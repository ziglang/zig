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
#ifndef _ASM_BYTEORDER_H
#define _ASM_BYTEORDER_H
#ifdef __MIPSEB__
#include <linux/byteorder/big_endian.h>
#elif defined(__MIPSEL__)
#include <linux/byteorder/little_endian.h>
#else
#error "MIPS, but neither __MIPSEB__, nor __MIPSEL__???"
#endif
#endif