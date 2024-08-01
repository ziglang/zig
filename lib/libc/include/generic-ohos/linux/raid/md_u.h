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
#ifndef _UAPI_MD_U_H
#define _UAPI_MD_U_H
#define MD_MAJOR_VERSION 0
#define MD_MINOR_VERSION 90
#define MD_PATCHLEVEL_VERSION 3
#define RAID_VERSION _IOR(MD_MAJOR, 0x10, mdu_version_t)
#define GET_ARRAY_INFO _IOR(MD_MAJOR, 0x11, mdu_array_info_t)
#define GET_DISK_INFO _IOR(MD_MAJOR, 0x12, mdu_disk_info_t)
#define RAID_AUTORUN _IO(MD_MAJOR, 0x14)
#define GET_BITMAP_FILE _IOR(MD_MAJOR, 0x15, mdu_bitmap_file_t)
#define CLEAR_ARRAY _IO(MD_MAJOR, 0x20)
#define ADD_NEW_DISK _IOW(MD_MAJOR, 0x21, mdu_disk_info_t)
#define HOT_REMOVE_DISK _IO(MD_MAJOR, 0x22)
#define SET_ARRAY_INFO _IOW(MD_MAJOR, 0x23, mdu_array_info_t)
#define SET_DISK_INFO _IO(MD_MAJOR, 0x24)
#define WRITE_RAID_INFO _IO(MD_MAJOR, 0x25)
#define UNPROTECT_ARRAY _IO(MD_MAJOR, 0x26)
#define PROTECT_ARRAY _IO(MD_MAJOR, 0x27)
#define HOT_ADD_DISK _IO(MD_MAJOR, 0x28)
#define SET_DISK_FAULTY _IO(MD_MAJOR, 0x29)
#define HOT_GENERATE_ERROR _IO(MD_MAJOR, 0x2a)
#define SET_BITMAP_FILE _IOW(MD_MAJOR, 0x2b, int)
#define RUN_ARRAY _IOW(MD_MAJOR, 0x30, mdu_param_t)
#define STOP_ARRAY _IO(MD_MAJOR, 0x32)
#define STOP_ARRAY_RO _IO(MD_MAJOR, 0x33)
#define RESTART_ARRAY_RW _IO(MD_MAJOR, 0x34)
#define CLUSTERED_DISK_NACK _IO(MD_MAJOR, 0x35)
#define MdpMinorShift 6
typedef struct mdu_version_s {
  int major;
  int minor;
  int patchlevel;
} mdu_version_t;
typedef struct mdu_array_info_s {
  int major_version;
  int minor_version;
  int patch_version;
  unsigned int ctime;
  int level;
  int size;
  int nr_disks;
  int raid_disks;
  int md_minor;
  int not_persistent;
  unsigned int utime;
  int state;
  int active_disks;
  int working_disks;
  int failed_disks;
  int spare_disks;
  int layout;
  int chunk_size;
} mdu_array_info_t;
#define LEVEL_MULTIPATH (- 4)
#define LEVEL_LINEAR (- 1)
#define LEVEL_FAULTY (- 5)
#define LEVEL_NONE (- 1000000)
typedef struct mdu_disk_info_s {
  int number;
  int major;
  int minor;
  int raid_disk;
  int state;
} mdu_disk_info_t;
typedef struct mdu_start_info_s {
  int major;
  int minor;
  int raid_disk;
  int state;
} mdu_start_info_t;
typedef struct mdu_bitmap_file_s {
  char pathname[4096];
} mdu_bitmap_file_t;
typedef struct mdu_param_s {
  int personality;
  int chunk_size;
  int max_fault;
} mdu_param_t;
#endif