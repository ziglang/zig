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
#ifndef _XT_IPVS_H
#define _XT_IPVS_H
#include <linux/types.h>
#include <linux/netfilter.h>
enum {
  XT_IPVS_IPVS_PROPERTY = 1 << 0,
  XT_IPVS_PROTO = 1 << 1,
  XT_IPVS_VADDR = 1 << 2,
  XT_IPVS_VPORT = 1 << 3,
  XT_IPVS_DIR = 1 << 4,
  XT_IPVS_METHOD = 1 << 5,
  XT_IPVS_VPORTCTL = 1 << 6,
  XT_IPVS_MASK = (1 << 7) - 1,
  XT_IPVS_ONCE_MASK = XT_IPVS_MASK & ~XT_IPVS_IPVS_PROPERTY
};
struct xt_ipvs_mtinfo {
  union nf_inet_addr vaddr, vmask;
  __be16 vport;
  __u8 l4proto;
  __u8 fwd_method;
  __be16 vportctl;
  __u8 invert;
  __u8 bitmask;
};
#endif