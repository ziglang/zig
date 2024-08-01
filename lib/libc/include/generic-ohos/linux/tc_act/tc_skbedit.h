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
#ifndef __LINUX_TC_SKBEDIT_H
#define __LINUX_TC_SKBEDIT_H
#include <linux/pkt_cls.h>
#define SKBEDIT_F_PRIORITY 0x1
#define SKBEDIT_F_QUEUE_MAPPING 0x2
#define SKBEDIT_F_MARK 0x4
#define SKBEDIT_F_PTYPE 0x8
#define SKBEDIT_F_MASK 0x10
#define SKBEDIT_F_INHERITDSFIELD 0x20
struct tc_skbedit {
  tc_gen;
};
enum {
  TCA_SKBEDIT_UNSPEC,
  TCA_SKBEDIT_TM,
  TCA_SKBEDIT_PARMS,
  TCA_SKBEDIT_PRIORITY,
  TCA_SKBEDIT_QUEUE_MAPPING,
  TCA_SKBEDIT_MARK,
  TCA_SKBEDIT_PAD,
  TCA_SKBEDIT_PTYPE,
  TCA_SKBEDIT_MASK,
  TCA_SKBEDIT_FLAGS,
  __TCA_SKBEDIT_MAX
};
#define TCA_SKBEDIT_MAX (__TCA_SKBEDIT_MAX - 1)
#endif