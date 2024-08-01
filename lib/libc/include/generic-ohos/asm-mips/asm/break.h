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
#ifndef __UAPI_ASM_BREAK_H
#define __UAPI_ASM_BREAK_H
#define BRK_USERBP 0
#define BRK_SSTEPBP 5
#define BRK_OVERFLOW 6
#define BRK_DIVZERO 7
#define BRK_RANGE 8
#define BRK_BUG 12
#define BRK_UPROBE 13
#define BRK_UPROBE_XOL 14
#define BRK_MEMU 514
#define BRK_KPROBE_BP 515
#define BRK_KPROBE_SSTEPBP 516
#define BRK_MULOVF 1023
#endif