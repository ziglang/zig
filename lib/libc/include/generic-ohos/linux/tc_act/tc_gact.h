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
#ifndef __LINUX_TC_GACT_H
#define __LINUX_TC_GACT_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
struct tc_gact {
  tc_gen;
};
struct tc_gact_p {
#define PGACT_NONE 0
#define PGACT_NETRAND 1
#define PGACT_DETERM 2
#define MAX_RAND (PGACT_DETERM + 1)
  __u16 ptype;
  __u16 pval;
  int paction;
};
enum {
  TCA_GACT_UNSPEC,
  TCA_GACT_TM,
  TCA_GACT_PARMS,
  TCA_GACT_PROB,
  TCA_GACT_PAD,
  __TCA_GACT_MAX
};
#define TCA_GACT_MAX (__TCA_GACT_MAX - 1)
#endif