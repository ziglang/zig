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
#ifndef _XT_RATE_H
#define _XT_RATE_H
#include <linux/types.h>
#define XT_LIMIT_SCALE 10000
struct xt_limit_priv;
struct xt_rateinfo {
  __u32 avg;
  __u32 burst;
  unsigned long prev;
  __u32 credit;
  __u32 credit_cap, cost;
  struct xt_limit_priv * master;
};
#endif