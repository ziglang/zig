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
#ifndef _LINUX_FSMAP_H
#define _LINUX_FSMAP_H
#include <linux/types.h>
struct fsmap {
  __u32 fmr_device;
  __u32 fmr_flags;
  __u64 fmr_physical;
  __u64 fmr_owner;
  __u64 fmr_offset;
  __u64 fmr_length;
  __u64 fmr_reserved[3];
};
struct fsmap_head {
  __u32 fmh_iflags;
  __u32 fmh_oflags;
  __u32 fmh_count;
  __u32 fmh_entries;
  __u64 fmh_reserved[6];
  struct fsmap fmh_keys[2];
  struct fsmap fmh_recs[];
};
#define FMH_IF_VALID 0
#define FMH_OF_DEV_T 0x1
#define FMR_OF_PREALLOC 0x1
#define FMR_OF_ATTR_FORK 0x2
#define FMR_OF_EXTENT_MAP 0x4
#define FMR_OF_SHARED 0x8
#define FMR_OF_SPECIAL_OWNER 0x10
#define FMR_OF_LAST 0x20
#define FMR_OWNER(type,code) (((__u64) type << 32) | ((__u64) code & 0xFFFFFFFFULL))
#define FMR_OWNER_TYPE(owner) ((__u32) ((__u64) owner >> 32))
#define FMR_OWNER_CODE(owner) ((__u32) (((__u64) owner & 0xFFFFFFFFULL)))
#define FMR_OWN_FREE FMR_OWNER(0, 1)
#define FMR_OWN_UNKNOWN FMR_OWNER(0, 2)
#define FMR_OWN_METADATA FMR_OWNER(0, 3)
#define FS_IOC_GETFSMAP _IOWR('X', 59, struct fsmap_head)
#endif