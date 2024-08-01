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
#ifndef __UAPI_TC_CTINFO_H
#define __UAPI_TC_CTINFO_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
struct tc_ctinfo {
  tc_gen;
};
enum {
  TCA_CTINFO_UNSPEC,
  TCA_CTINFO_PAD,
  TCA_CTINFO_TM,
  TCA_CTINFO_ACT,
  TCA_CTINFO_ZONE,
  TCA_CTINFO_PARMS_DSCP_MASK,
  TCA_CTINFO_PARMS_DSCP_STATEMASK,
  TCA_CTINFO_PARMS_CPMARK_MASK,
  TCA_CTINFO_STATS_DSCP_SET,
  TCA_CTINFO_STATS_DSCP_ERROR,
  TCA_CTINFO_STATS_CPMARK_SET,
  __TCA_CTINFO_MAX
};
#define TCA_CTINFO_MAX (__TCA_CTINFO_MAX - 1)
#endif