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
#ifndef _LINUX_TERMIOS_H
#define _LINUX_TERMIOS_H
#include <linux/types.h>
#include <asm/termios.h>
#define NFF 5
struct termiox {
  __u16 x_hflag;
  __u16 x_cflag;
  __u16 x_rflag[NFF];
  __u16 x_sflag;
};
#define RTSXOFF 0x0001
#define CTSXON 0x0002
#define DTRXOFF 0x0004
#define DSRXON 0x0008
#endif