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
#ifndef _LINUX_NETFILTER_XT_L2TP_H
#define _LINUX_NETFILTER_XT_L2TP_H
#include <linux/types.h>
enum xt_l2tp_type {
  XT_L2TP_TYPE_CONTROL,
  XT_L2TP_TYPE_DATA,
};
struct xt_l2tp_info {
  __u32 tid;
  __u32 sid;
  __u8 version;
  __u8 type;
  __u8 flags;
};
enum {
  XT_L2TP_TID = (1 << 0),
  XT_L2TP_SID = (1 << 1),
  XT_L2TP_VERSION = (1 << 2),
  XT_L2TP_TYPE = (1 << 3),
};
#endif