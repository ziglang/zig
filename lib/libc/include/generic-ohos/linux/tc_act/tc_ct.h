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
#ifndef __UAPI_TC_CT_H
#define __UAPI_TC_CT_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
enum {
  TCA_CT_UNSPEC,
  TCA_CT_PARMS,
  TCA_CT_TM,
  TCA_CT_ACTION,
  TCA_CT_ZONE,
  TCA_CT_MARK,
  TCA_CT_MARK_MASK,
  TCA_CT_LABELS,
  TCA_CT_LABELS_MASK,
  TCA_CT_NAT_IPV4_MIN,
  TCA_CT_NAT_IPV4_MAX,
  TCA_CT_NAT_IPV6_MIN,
  TCA_CT_NAT_IPV6_MAX,
  TCA_CT_NAT_PORT_MIN,
  TCA_CT_NAT_PORT_MAX,
  TCA_CT_PAD,
  __TCA_CT_MAX
};
#define TCA_CT_MAX (__TCA_CT_MAX - 1)
#define TCA_CT_ACT_COMMIT (1 << 0)
#define TCA_CT_ACT_FORCE (1 << 1)
#define TCA_CT_ACT_CLEAR (1 << 2)
#define TCA_CT_ACT_NAT (1 << 3)
#define TCA_CT_ACT_NAT_SRC (1 << 4)
#define TCA_CT_ACT_NAT_DST (1 << 5)
struct tc_ct {
  tc_gen;
};
#endif