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
#ifndef _UAPI__CRAMFS_H
#define _UAPI__CRAMFS_H
#include <linux/types.h>
#include <linux/magic.h>
#define CRAMFS_SIGNATURE "Compressed ROMFS"
#define CRAMFS_MODE_WIDTH 16
#define CRAMFS_UID_WIDTH 16
#define CRAMFS_SIZE_WIDTH 24
#define CRAMFS_GID_WIDTH 8
#define CRAMFS_NAMELEN_WIDTH 6
#define CRAMFS_OFFSET_WIDTH 26
#define CRAMFS_MAXPATHLEN (((1 << CRAMFS_NAMELEN_WIDTH) - 1) << 2)
struct cramfs_inode {
  __u32 mode : CRAMFS_MODE_WIDTH, uid : CRAMFS_UID_WIDTH;
  __u32 size : CRAMFS_SIZE_WIDTH, gid : CRAMFS_GID_WIDTH;
  __u32 namelen : CRAMFS_NAMELEN_WIDTH, offset : CRAMFS_OFFSET_WIDTH;
};
struct cramfs_info {
  __u32 crc;
  __u32 edition;
  __u32 blocks;
  __u32 files;
};
struct cramfs_super {
  __u32 magic;
  __u32 size;
  __u32 flags;
  __u32 future;
  __u8 signature[16];
  struct cramfs_info fsid;
  __u8 name[16];
  struct cramfs_inode root;
};
#define CRAMFS_FLAG_FSID_VERSION_2 0x00000001
#define CRAMFS_FLAG_SORTED_DIRS 0x00000002
#define CRAMFS_FLAG_HOLES 0x00000100
#define CRAMFS_FLAG_WRONG_SIGNATURE 0x00000200
#define CRAMFS_FLAG_SHIFTED_ROOT_OFFSET 0x00000400
#define CRAMFS_FLAG_EXT_BLOCK_POINTERS 0x00000800
#define CRAMFS_SUPPORTED_FLAGS (0x000000ff | CRAMFS_FLAG_HOLES | CRAMFS_FLAG_WRONG_SIGNATURE | CRAMFS_FLAG_SHIFTED_ROOT_OFFSET | CRAMFS_FLAG_EXT_BLOCK_POINTERS)
#define CRAMFS_BLK_FLAG_UNCOMPRESSED (1 << 31)
#define CRAMFS_BLK_FLAG_DIRECT_PTR (1 << 30)
#define CRAMFS_BLK_FLAGS (CRAMFS_BLK_FLAG_UNCOMPRESSED | CRAMFS_BLK_FLAG_DIRECT_PTR)
#define CRAMFS_BLK_DIRECT_PTR_SHIFT 2
#endif