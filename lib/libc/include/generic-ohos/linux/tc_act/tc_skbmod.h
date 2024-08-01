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
#ifndef __LINUX_TC_SKBMOD_H
#define __LINUX_TC_SKBMOD_H
#include <linux/pkt_cls.h>
#define SKBMOD_F_DMAC 0x1
#define SKBMOD_F_SMAC 0x2
#define SKBMOD_F_ETYPE 0x4
#define SKBMOD_F_SWAPMAC 0x8
struct tc_skbmod {
  tc_gen;
  __u64 flags;
};
enum {
  TCA_SKBMOD_UNSPEC,
  TCA_SKBMOD_TM,
  TCA_SKBMOD_PARMS,
  TCA_SKBMOD_DMAC,
  TCA_SKBMOD_SMAC,
  TCA_SKBMOD_ETYPE,
  TCA_SKBMOD_PAD,
  __TCA_SKBMOD_MAX
};
#define TCA_SKBMOD_MAX (__TCA_SKBMOD_MAX - 1)
#endif