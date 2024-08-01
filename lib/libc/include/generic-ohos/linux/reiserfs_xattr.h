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
#ifndef _LINUX_REISERFS_XATTR_H
#define _LINUX_REISERFS_XATTR_H
#include <linux/types.h>
#define REISERFS_XATTR_MAGIC 0x52465841
struct reiserfs_xattr_header {
  __le32 h_magic;
  __le32 h_hash;
};
struct reiserfs_security_handle {
  const char * name;
  void * value;
  size_t length;
};
#endif