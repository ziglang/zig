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
#ifndef _XT_DEVGROUP_H
#define _XT_DEVGROUP_H
#include <linux/types.h>
enum xt_devgroup_flags {
  XT_DEVGROUP_MATCH_SRC = 0x1,
  XT_DEVGROUP_INVERT_SRC = 0x2,
  XT_DEVGROUP_MATCH_DST = 0x4,
  XT_DEVGROUP_INVERT_DST = 0x8,
};
struct xt_devgroup_info {
  __u32 flags;
  __u32 src_group;
  __u32 src_mask;
  __u32 dst_group;
  __u32 dst_mask;
};
#endif