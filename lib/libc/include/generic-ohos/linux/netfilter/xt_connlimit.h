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
#ifndef _XT_CONNLIMIT_H
#define _XT_CONNLIMIT_H
#include <linux/types.h>
#include <linux/netfilter.h>
struct xt_connlimit_data;
enum {
  XT_CONNLIMIT_INVERT = 1 << 0,
  XT_CONNLIMIT_DADDR = 1 << 1,
};
struct xt_connlimit_info {
  union {
    union nf_inet_addr mask;
    union {
      __be32 v4_mask;
      __be32 v6_mask[4];
    };
  };
  unsigned int limit;
  __u32 flags;
  struct nf_conncount_data * data __attribute__((aligned(8)));
};
#endif