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
#ifndef _XT_TPROXY_H
#define _XT_TPROXY_H
#include <linux/types.h>
#include <linux/netfilter.h>
struct xt_tproxy_target_info {
  __u32 mark_mask;
  __u32 mark_value;
  __be32 laddr;
  __be16 lport;
};
struct xt_tproxy_target_info_v1 {
  __u32 mark_mask;
  __u32 mark_value;
  union nf_inet_addr laddr;
  __be16 lport;
};
#endif