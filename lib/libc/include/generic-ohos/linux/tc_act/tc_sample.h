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
#ifndef __LINUX_TC_SAMPLE_H
#define __LINUX_TC_SAMPLE_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
#include <linux/if_ether.h>
struct tc_sample {
  tc_gen;
};
enum {
  TCA_SAMPLE_UNSPEC,
  TCA_SAMPLE_TM,
  TCA_SAMPLE_PARMS,
  TCA_SAMPLE_RATE,
  TCA_SAMPLE_TRUNC_SIZE,
  TCA_SAMPLE_PSAMPLE_GROUP,
  TCA_SAMPLE_PAD,
  __TCA_SAMPLE_MAX
};
#define TCA_SAMPLE_MAX (__TCA_SAMPLE_MAX - 1)
#endif