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
#ifndef _LINUX_NETFILTER_XT_RECENT_H
#define _LINUX_NETFILTER_XT_RECENT_H 1
#include <linux/types.h>
#include <linux/netfilter.h>
enum {
  XT_RECENT_CHECK = 1 << 0,
  XT_RECENT_SET = 1 << 1,
  XT_RECENT_UPDATE = 1 << 2,
  XT_RECENT_REMOVE = 1 << 3,
  XT_RECENT_TTL = 1 << 4,
  XT_RECENT_REAP = 1 << 5,
  XT_RECENT_SOURCE = 0,
  XT_RECENT_DEST = 1,
  XT_RECENT_NAME_LEN = 200,
};
#define XT_RECENT_MODIFIERS (XT_RECENT_TTL | XT_RECENT_REAP)
#define XT_RECENT_VALID_FLAGS (XT_RECENT_CHECK | XT_RECENT_SET | XT_RECENT_UPDATE | XT_RECENT_REMOVE | XT_RECENT_TTL | XT_RECENT_REAP)
struct xt_recent_mtinfo {
  __u32 seconds;
  __u32 hit_count;
  __u8 check_set;
  __u8 invert;
  char name[XT_RECENT_NAME_LEN];
  __u8 side;
};
struct xt_recent_mtinfo_v1 {
  __u32 seconds;
  __u32 hit_count;
  __u8 check_set;
  __u8 invert;
  char name[XT_RECENT_NAME_LEN];
  __u8 side;
  union nf_inet_addr mask;
};
#endif