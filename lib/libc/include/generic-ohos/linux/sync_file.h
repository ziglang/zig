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
#ifndef _UAPI_LINUX_SYNC_H
#define _UAPI_LINUX_SYNC_H
#include <linux/ioctl.h>
#include <linux/types.h>
struct sync_merge_data {
  char name[32];
  __s32 fd2;
  __s32 fence;
  __u32 flags;
  __u32 pad;
};
struct sync_fence_info {
  char obj_name[32];
  char driver_name[32];
  __s32 status;
  __u32 flags;
  __u64 timestamp_ns;
};
struct sync_file_info {
  char name[32];
  __s32 status;
  __u32 flags;
  __u32 num_fences;
  __u32 pad;
  __u64 sync_fence_info;
};
#define SYNC_IOC_MAGIC '>'
#define SYNC_IOC_MERGE _IOWR(SYNC_IOC_MAGIC, 3, struct sync_merge_data)
#define SYNC_IOC_FILE_INFO _IOWR(SYNC_IOC_MAGIC, 4, struct sync_file_info)
#endif