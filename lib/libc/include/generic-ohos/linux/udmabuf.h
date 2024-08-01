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
#ifndef _UAPI_LINUX_UDMABUF_H
#define _UAPI_LINUX_UDMABUF_H
#include <linux/types.h>
#include <linux/ioctl.h>
#define UDMABUF_FLAGS_CLOEXEC 0x01
struct udmabuf_create {
  __u32 memfd;
  __u32 flags;
  __u64 offset;
  __u64 size;
};
struct udmabuf_create_item {
  __u32 memfd;
  __u32 __pad;
  __u64 offset;
  __u64 size;
};
struct udmabuf_create_list {
  __u32 flags;
  __u32 count;
  struct udmabuf_create_item list[];
};
#define UDMABUF_CREATE _IOW('u', 0x42, struct udmabuf_create)
#define UDMABUF_CREATE_LIST _IOW('u', 0x43, struct udmabuf_create_list)
#endif