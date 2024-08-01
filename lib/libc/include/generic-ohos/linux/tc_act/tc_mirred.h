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
#ifndef __LINUX_TC_MIR_H
#define __LINUX_TC_MIR_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
#define TCA_EGRESS_REDIR 1
#define TCA_EGRESS_MIRROR 2
#define TCA_INGRESS_REDIR 3
#define TCA_INGRESS_MIRROR 4
struct tc_mirred {
  tc_gen;
  int eaction;
  __u32 ifindex;
};
enum {
  TCA_MIRRED_UNSPEC,
  TCA_MIRRED_TM,
  TCA_MIRRED_PARMS,
  TCA_MIRRED_PAD,
  __TCA_MIRRED_MAX
};
#define TCA_MIRRED_MAX (__TCA_MIRRED_MAX - 1)
#endif