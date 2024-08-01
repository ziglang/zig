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
#ifndef __UAPI_TC_CONNMARK_H
#define __UAPI_TC_CONNMARK_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
struct tc_connmark {
  tc_gen;
  __u16 zone;
};
enum {
  TCA_CONNMARK_UNSPEC,
  TCA_CONNMARK_PARMS,
  TCA_CONNMARK_TM,
  TCA_CONNMARK_PAD,
  __TCA_CONNMARK_MAX
};
#define TCA_CONNMARK_MAX (__TCA_CONNMARK_MAX - 1)
#endif