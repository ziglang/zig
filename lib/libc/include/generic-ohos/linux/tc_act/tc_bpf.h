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
#ifndef __LINUX_TC_BPF_H
#define __LINUX_TC_BPF_H
#include <linux/pkt_cls.h>
struct tc_act_bpf {
  tc_gen;
};
enum {
  TCA_ACT_BPF_UNSPEC,
  TCA_ACT_BPF_TM,
  TCA_ACT_BPF_PARMS,
  TCA_ACT_BPF_OPS_LEN,
  TCA_ACT_BPF_OPS,
  TCA_ACT_BPF_FD,
  TCA_ACT_BPF_NAME,
  TCA_ACT_BPF_PAD,
  TCA_ACT_BPF_TAG,
  TCA_ACT_BPF_ID,
  __TCA_ACT_BPF_MAX,
};
#define TCA_ACT_BPF_MAX (__TCA_ACT_BPF_MAX - 1)
#endif