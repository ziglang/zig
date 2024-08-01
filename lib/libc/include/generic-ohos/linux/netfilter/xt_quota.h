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
#ifndef _XT_QUOTA_H
#define _XT_QUOTA_H
#include <linux/types.h>
enum xt_quota_flags {
  XT_QUOTA_INVERT = 0x1,
};
#define XT_QUOTA_MASK 0x1
struct xt_quota_priv;
struct xt_quota_info {
  __u32 flags;
  __u32 pad;
  __aligned_u64 quota;
  struct xt_quota_priv * master;
};
#endif