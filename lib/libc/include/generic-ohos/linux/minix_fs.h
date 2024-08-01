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
#ifndef _LINUX_MINIX_FS_H
#define _LINUX_MINIX_FS_H
#include <linux/types.h>
#include <linux/magic.h>
#define MINIX_ROOT_INO 1
#define MINIX_LINK_MAX 250
#define MINIX2_LINK_MAX 65530
#define MINIX_I_MAP_SLOTS 8
#define MINIX_Z_MAP_SLOTS 64
#define MINIX_VALID_FS 0x0001
#define MINIX_ERROR_FS 0x0002
#define MINIX_INODES_PER_BLOCK ((BLOCK_SIZE) / (sizeof(struct minix_inode)))
struct minix_inode {
  __u16 i_mode;
  __u16 i_uid;
  __u32 i_size;
  __u32 i_time;
  __u8 i_gid;
  __u8 i_nlinks;
  __u16 i_zone[9];
};
struct minix2_inode {
  __u16 i_mode;
  __u16 i_nlinks;
  __u16 i_uid;
  __u16 i_gid;
  __u32 i_size;
  __u32 i_atime;
  __u32 i_mtime;
  __u32 i_ctime;
  __u32 i_zone[10];
};
struct minix_super_block {
  __u16 s_ninodes;
  __u16 s_nzones;
  __u16 s_imap_blocks;
  __u16 s_zmap_blocks;
  __u16 s_firstdatazone;
  __u16 s_log_zone_size;
  __u32 s_max_size;
  __u16 s_magic;
  __u16 s_state;
  __u32 s_zones;
};
struct minix3_super_block {
  __u32 s_ninodes;
  __u16 s_pad0;
  __u16 s_imap_blocks;
  __u16 s_zmap_blocks;
  __u16 s_firstdatazone;
  __u16 s_log_zone_size;
  __u16 s_pad1;
  __u32 s_max_size;
  __u32 s_zones;
  __u16 s_magic;
  __u16 s_pad2;
  __u16 s_blocksize;
  __u8 s_disk_version;
};
struct minix_dir_entry {
  __u16 inode;
  char name[0];
};
struct minix3_dir_entry {
  __u32 inode;
  char name[0];
};
#endif