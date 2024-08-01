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
#ifndef _IPT_TTL_H
#define _IPT_TTL_H
#include <linux/types.h>
enum {
  IPT_TTL_SET = 0,
  IPT_TTL_INC,
  IPT_TTL_DEC
};
#define IPT_TTL_MAXMODE IPT_TTL_DEC
struct ipt_TTL_info {
  __u8 mode;
  __u8 ttl;
};
#endif