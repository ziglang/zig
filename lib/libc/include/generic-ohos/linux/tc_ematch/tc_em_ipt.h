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
#ifndef __LINUX_TC_EM_IPT_H
#define __LINUX_TC_EM_IPT_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
enum {
  TCA_EM_IPT_UNSPEC,
  TCA_EM_IPT_HOOK,
  TCA_EM_IPT_MATCH_NAME,
  TCA_EM_IPT_MATCH_REVISION,
  TCA_EM_IPT_NFPROTO,
  TCA_EM_IPT_MATCH_DATA,
  __TCA_EM_IPT_MAX
};
#define TCA_EM_IPT_MAX (__TCA_EM_IPT_MAX - 1)
#endif