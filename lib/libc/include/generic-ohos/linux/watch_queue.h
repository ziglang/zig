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
#ifndef _UAPI_LINUX_WATCH_QUEUE_H
#define _UAPI_LINUX_WATCH_QUEUE_H
#include <linux/types.h>
#include <linux/fcntl.h>
#include <linux/ioctl.h>
#define O_NOTIFICATION_PIPE O_EXCL
#define IOC_WATCH_QUEUE_SET_SIZE _IO('W', 0x60)
#define IOC_WATCH_QUEUE_SET_FILTER _IO('W', 0x61)
enum watch_notification_type {
  WATCH_TYPE_META = 0,
  WATCH_TYPE_KEY_NOTIFY = 1,
  WATCH_TYPE__NR = 2
};
enum watch_meta_notification_subtype {
  WATCH_META_REMOVAL_NOTIFICATION = 0,
  WATCH_META_LOSS_NOTIFICATION = 1,
};
struct watch_notification {
  __u32 type : 24;
  __u32 subtype : 8;
  __u32 info;
#define WATCH_INFO_LENGTH 0x0000007f
#define WATCH_INFO_LENGTH__SHIFT 0
#define WATCH_INFO_ID 0x0000ff00
#define WATCH_INFO_ID__SHIFT 8
#define WATCH_INFO_TYPE_INFO 0xffff0000
#define WATCH_INFO_TYPE_INFO__SHIFT 16
#define WATCH_INFO_FLAG_0 0x00010000
#define WATCH_INFO_FLAG_1 0x00020000
#define WATCH_INFO_FLAG_2 0x00040000
#define WATCH_INFO_FLAG_3 0x00080000
#define WATCH_INFO_FLAG_4 0x00100000
#define WATCH_INFO_FLAG_5 0x00200000
#define WATCH_INFO_FLAG_6 0x00400000
#define WATCH_INFO_FLAG_7 0x00800000
};
struct watch_notification_type_filter {
  __u32 type;
  __u32 info_filter;
  __u32 info_mask;
  __u32 subtype_filter[8];
};
struct watch_notification_filter {
  __u32 nr_filters;
  __u32 __reserved;
  struct watch_notification_type_filter filters[];
};
struct watch_notification_removal {
  struct watch_notification watch;
  __u64 id;
};
enum key_notification_subtype {
  NOTIFY_KEY_INSTANTIATED = 0,
  NOTIFY_KEY_UPDATED = 1,
  NOTIFY_KEY_LINKED = 2,
  NOTIFY_KEY_UNLINKED = 3,
  NOTIFY_KEY_CLEARED = 4,
  NOTIFY_KEY_REVOKED = 5,
  NOTIFY_KEY_INVALIDATED = 6,
  NOTIFY_KEY_SETATTR = 7,
};
struct key_notification {
  struct watch_notification watch;
  __u32 key_id;
  __u32 aux;
};
#endif