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
#ifndef __LINUX_TC_NAT_H
#define __LINUX_TC_NAT_H
#include <linux/pkt_cls.h>
#include <linux/types.h>
enum {
  TCA_NAT_UNSPEC,
  TCA_NAT_PARMS,
  TCA_NAT_TM,
  TCA_NAT_PAD,
  __TCA_NAT_MAX
};
#define TCA_NAT_MAX (__TCA_NAT_MAX - 1)
#define TCA_NAT_FLAG_EGRESS 1
struct tc_nat {
  tc_gen;
  __be32 old_addr;
  __be32 new_addr;
  __be32 mask;
  __u32 flags;
};
#endif