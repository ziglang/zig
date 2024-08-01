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
#ifndef __LINUX_TC_DEF_H
#define __LINUX_TC_DEF_H
#include <linux/pkt_cls.h>
struct tc_defact {
  tc_gen;
};
enum {
  TCA_DEF_UNSPEC,
  TCA_DEF_TM,
  TCA_DEF_PARMS,
  TCA_DEF_DATA,
  TCA_DEF_PAD,
  __TCA_DEF_MAX
};
#define TCA_DEF_MAX (__TCA_DEF_MAX - 1)
#endif