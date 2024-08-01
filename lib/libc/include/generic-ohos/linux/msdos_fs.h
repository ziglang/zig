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
#ifndef _UAPI_LINUX_MSDOS_FS_H
#define _UAPI_LINUX_MSDOS_FS_H
#include <linux/types.h>
#include <linux/magic.h>
#include <asm/byteorder.h>
#ifndef SECTOR_SIZE
#define SECTOR_SIZE 512
#endif
#define SECTOR_BITS 9
#define MSDOS_DPB (MSDOS_DPS)
#define MSDOS_DPB_BITS 4
#define MSDOS_DPS (SECTOR_SIZE / sizeof(struct msdos_dir_entry))
#define MSDOS_DPS_BITS 4
#define MSDOS_LONGNAME 256
#define CF_LE_W(v) le16_to_cpu(v)
#define CF_LE_L(v) le32_to_cpu(v)
#define CT_LE_W(v) cpu_to_le16(v)
#define CT_LE_L(v) cpu_to_le32(v)
#define MSDOS_ROOT_INO 1
#define MSDOS_FSINFO_INO 2
#define MSDOS_DIR_BITS 5
#define FAT_MAX_DIR_ENTRIES (65536)
#define FAT_MAX_DIR_SIZE (FAT_MAX_DIR_ENTRIES << MSDOS_DIR_BITS)
#define ATTR_NONE 0
#define ATTR_RO 1
#define ATTR_HIDDEN 2
#define ATTR_SYS 4
#define ATTR_VOLUME 8
#define ATTR_DIR 16
#define ATTR_ARCH 32
#define ATTR_UNUSED (ATTR_VOLUME | ATTR_ARCH | ATTR_SYS | ATTR_HIDDEN)
#define ATTR_EXT (ATTR_RO | ATTR_HIDDEN | ATTR_SYS | ATTR_VOLUME)
#define CASE_LOWER_BASE 8
#define CASE_LOWER_EXT 16
#define DELETED_FLAG 0xe5
#define IS_FREE(n) (! * (n) || * (n) == DELETED_FLAG)
#define FAT_LFN_LEN 255
#define MSDOS_NAME 11
#define MSDOS_SLOTS 21
#define MSDOS_DOT ".          "
#define MSDOS_DOTDOT "..         "
#define FAT_START_ENT 2
#define MAX_FAT12 0xFF4
#define MAX_FAT16 0xFFF4
#define MAX_FAT32 0x0FFFFFF6
#define BAD_FAT12 0xFF7
#define BAD_FAT16 0xFFF7
#define BAD_FAT32 0x0FFFFFF7
#define EOF_FAT12 0xFFF
#define EOF_FAT16 0xFFFF
#define EOF_FAT32 0x0FFFFFFF
#define FAT_ENT_FREE (0)
#define FAT_ENT_BAD (BAD_FAT32)
#define FAT_ENT_EOF (EOF_FAT32)
#define FAT_FSINFO_SIG1 0x41615252
#define FAT_FSINFO_SIG2 0x61417272
#define IS_FSINFO(x) (le32_to_cpu((x)->signature1) == FAT_FSINFO_SIG1 && le32_to_cpu((x)->signature2) == FAT_FSINFO_SIG2)
#define FAT_STATE_DIRTY 0x01
struct __fat_dirent {
  long d_ino;
  __kernel_off_t d_off;
  unsigned short d_reclen;
  char d_name[256];
};
#define VFAT_IOCTL_READDIR_BOTH _IOR('r', 1, struct __fat_dirent[2])
#define VFAT_IOCTL_READDIR_SHORT _IOR('r', 2, struct __fat_dirent[2])
#define FAT_IOCTL_GET_ATTRIBUTES _IOR('r', 0x10, __u32)
#define FAT_IOCTL_SET_ATTRIBUTES _IOW('r', 0x11, __u32)
#define FAT_IOCTL_GET_VOLUME_ID _IOR('r', 0x13, __u32)
struct fat_boot_sector {
  __u8 ignored[3];
  __u8 system_id[8];
  __u8 sector_size[2];
  __u8 sec_per_clus;
  __le16 reserved;
  __u8 fats;
  __u8 dir_entries[2];
  __u8 sectors[2];
  __u8 media;
  __le16 fat_length;
  __le16 secs_track;
  __le16 heads;
  __le32 hidden;
  __le32 total_sect;
  union {
    struct {
      __u8 drive_number;
      __u8 state;
      __u8 signature;
      __u8 vol_id[4];
      __u8 vol_label[MSDOS_NAME];
      __u8 fs_type[8];
    } fat16;
    struct {
      __le32 length;
      __le16 flags;
      __u8 version[2];
      __le32 root_cluster;
      __le16 info_sector;
      __le16 backup_boot;
      __le16 reserved2[6];
      __u8 drive_number;
      __u8 state;
      __u8 signature;
      __u8 vol_id[4];
      __u8 vol_label[MSDOS_NAME];
      __u8 fs_type[8];
    } fat32;
  };
};
struct fat_boot_fsinfo {
  __le32 signature1;
  __le32 reserved1[120];
  __le32 signature2;
  __le32 free_clusters;
  __le32 next_cluster;
  __le32 reserved2[4];
};
struct msdos_dir_entry {
  __u8 name[MSDOS_NAME];
  __u8 attr;
  __u8 lcase;
  __u8 ctime_cs;
  __le16 ctime;
  __le16 cdate;
  __le16 adate;
  __le16 starthi;
  __le16 time, date, start;
  __le32 size;
};
struct msdos_dir_slot {
  __u8 id;
  __u8 name0_4[10];
  __u8 attr;
  __u8 reserved;
  __u8 alias_checksum;
  __u8 name5_10[12];
  __le16 start;
  __u8 name11_12[4];
};
#endif