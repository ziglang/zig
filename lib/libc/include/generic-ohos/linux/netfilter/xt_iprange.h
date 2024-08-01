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
#ifndef _LINUX_NETFILTER_XT_IPRANGE_H
#define _LINUX_NETFILTER_XT_IPRANGE_H 1
#include <linux/types.h>
#include <linux/netfilter.h>
enum {
  IPRANGE_SRC = 1 << 0,
  IPRANGE_DST = 1 << 1,
  IPRANGE_SRC_INV = 1 << 4,
  IPRANGE_DST_INV = 1 << 5,
};
struct xt_iprange_mtinfo {
  union nf_inet_addr src_min, src_max;
  union nf_inet_addr dst_min, dst_max;
  __u8 flags;
};
#endif