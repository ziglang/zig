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
#ifndef __LINUX_TC_CSUM_H
#define __LINUX_TC_CSUM_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
enum {
  TCA_CSUM_UNSPEC,
  TCA_CSUM_PARMS,
  TCA_CSUM_TM,
  TCA_CSUM_PAD,
  __TCA_CSUM_MAX
};
#define TCA_CSUM_MAX (__TCA_CSUM_MAX - 1)
enum {
  TCA_CSUM_UPDATE_FLAG_IPV4HDR = 1,
  TCA_CSUM_UPDATE_FLAG_ICMP = 2,
  TCA_CSUM_UPDATE_FLAG_IGMP = 4,
  TCA_CSUM_UPDATE_FLAG_TCP = 8,
  TCA_CSUM_UPDATE_FLAG_UDP = 16,
  TCA_CSUM_UPDATE_FLAG_UDPLITE = 32,
  TCA_CSUM_UPDATE_FLAG_SCTP = 64,
};
struct tc_csum {
  tc_gen;
  __u32 update_flags;
};
#endif