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
#ifndef _UAPI__LINUX_BLKPG_H
#define _UAPI__LINUX_BLKPG_H
#include <linux/compiler.h>
#include <linux/ioctl.h>
#define BLKPG _IO(0x12, 105)
struct blkpg_ioctl_arg {
  int op;
  int flags;
  int datalen;
  void __user * data;
};
#define BLKPG_ADD_PARTITION 1
#define BLKPG_DEL_PARTITION 2
#define BLKPG_RESIZE_PARTITION 3
#define BLKPG_DEVNAMELTH 64
#define BLKPG_VOLNAMELTH 64
struct blkpg_partition {
  long long start;
  long long length;
  int pno;
  char devname[BLKPG_DEVNAMELTH];
  char volname[BLKPG_VOLNAMELTH];
};
#endif