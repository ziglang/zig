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
#ifndef _UAPI_LINUX_FIEMAP_H
#define _UAPI_LINUX_FIEMAP_H
#include <linux/types.h>
struct fiemap_extent {
  __u64 fe_logical;
  __u64 fe_physical;
  __u64 fe_length;
  __u64 fe_reserved64[2];
  __u32 fe_flags;
  __u32 fe_reserved[3];
};
struct fiemap {
  __u64 fm_start;
  __u64 fm_length;
  __u32 fm_flags;
  __u32 fm_mapped_extents;
  __u32 fm_extent_count;
  __u32 fm_reserved;
  struct fiemap_extent fm_extents[0];
};
#define FIEMAP_MAX_OFFSET (~0ULL)
#define FIEMAP_FLAG_SYNC 0x00000001
#define FIEMAP_FLAG_XATTR 0x00000002
#define FIEMAP_FLAG_CACHE 0x00000004
#define FIEMAP_FLAGS_COMPAT (FIEMAP_FLAG_SYNC | FIEMAP_FLAG_XATTR)
#define FIEMAP_EXTENT_LAST 0x00000001
#define FIEMAP_EXTENT_UNKNOWN 0x00000002
#define FIEMAP_EXTENT_DELALLOC 0x00000004
#define FIEMAP_EXTENT_ENCODED 0x00000008
#define FIEMAP_EXTENT_DATA_ENCRYPTED 0x00000080
#define FIEMAP_EXTENT_NOT_ALIGNED 0x00000100
#define FIEMAP_EXTENT_DATA_INLINE 0x00000200
#define FIEMAP_EXTENT_DATA_TAIL 0x00000400
#define FIEMAP_EXTENT_UNWRITTEN 0x00000800
#define FIEMAP_EXTENT_MERGED 0x00001000
#define FIEMAP_EXTENT_SHARED 0x00002000
#endif