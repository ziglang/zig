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
#ifndef _LINUX_IF_PLIP_H
#define _LINUX_IF_PLIP_H
#include <linux/sockios.h>
#define SIOCDEVPLIP SIOCDEVPRIVATE
struct plipconf {
  unsigned short pcmd;
  unsigned long nibble;
  unsigned long trigger;
};
#define PLIP_GET_TIMEOUT 0x1
#define PLIP_SET_TIMEOUT 0x2
#endif