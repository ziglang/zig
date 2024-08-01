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
#ifndef __UAPI_TC_IFE_H
#define __UAPI_TC_IFE_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
#include <linux/ife.h>
#define IFE_ENCODE 1
#define IFE_DECODE 0
struct tc_ife {
  tc_gen;
  __u16 flags;
};
enum {
  TCA_IFE_UNSPEC,
  TCA_IFE_PARMS,
  TCA_IFE_TM,
  TCA_IFE_DMAC,
  TCA_IFE_SMAC,
  TCA_IFE_TYPE,
  TCA_IFE_METALST,
  TCA_IFE_PAD,
  __TCA_IFE_MAX
};
#define TCA_IFE_MAX (__TCA_IFE_MAX - 1)
#endif