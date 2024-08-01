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
#ifndef _UAPI_LINUX_BINDERFS_H
#define _UAPI_LINUX_BINDERFS_H
#include <linux/android/binder.h>
#include <linux/types.h>
#include <linux/ioctl.h>
#define BINDERFS_MAX_NAME 255
struct binderfs_device {
  char name[BINDERFS_MAX_NAME + 1];
  __u32 major;
  __u32 minor;
};
#define BINDER_CTL_ADD _IOWR('b', 1, struct binderfs_device)
#endif