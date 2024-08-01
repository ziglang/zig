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
#ifndef __LINUX_BRIDGE_EBT_LIMIT_H
#define __LINUX_BRIDGE_EBT_LIMIT_H
#include <linux/types.h>
#define EBT_LIMIT_MATCH "limit"
#define EBT_LIMIT_SCALE 10000
struct ebt_limit_info {
  __u32 avg;
  __u32 burst;
  unsigned long prev;
  __u32 credit;
  __u32 credit_cap, cost;
};
#endif