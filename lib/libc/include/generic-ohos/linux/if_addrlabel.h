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
#ifndef __LINUX_IF_ADDRLABEL_H
#define __LINUX_IF_ADDRLABEL_H
#include <linux/types.h>
struct ifaddrlblmsg {
  __u8 ifal_family;
  __u8 __ifal_reserved;
  __u8 ifal_prefixlen;
  __u8 ifal_flags;
  __u32 ifal_index;
  __u32 ifal_seq;
};
enum {
  IFAL_ADDRESS = 1,
  IFAL_LABEL = 2,
  __IFAL_MAX
};
#define IFAL_MAX (__IFAL_MAX - 1)
#endif