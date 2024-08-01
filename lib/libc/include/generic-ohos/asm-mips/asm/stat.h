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
#ifndef _ASM_STAT_H
#define _ASM_STAT_H
#include <linux/types.h>
#include <asm/sgidefs.h>
#if _MIPS_SIM == _MIPS_SIM_ABI32 || _MIPS_SIM == _MIPS_SIM_NABI32
struct stat {
  unsigned st_dev;
  long st_pad1[3];
  ino_t st_ino;
  mode_t st_mode;
  __u32 st_nlink;
  uid_t st_uid;
  gid_t st_gid;
  unsigned st_rdev;
  long st_pad2[2];
  long st_size;
  long st_pad3;
  long st_atime;
  long st_atime_nsec;
  long st_mtime;
  long st_mtime_nsec;
  long st_ctime;
  long st_ctime_nsec;
  long st_blksize;
  long st_blocks;
  long st_pad4[14];
};
struct stat64 {
  unsigned long st_dev;
  unsigned long st_pad0[3];
  unsigned long long st_ino;
  mode_t st_mode;
  __u32 st_nlink;
  uid_t st_uid;
  gid_t st_gid;
  unsigned long st_rdev;
  unsigned long st_pad1[3];
  long long st_size;
  long st_atime;
  unsigned long st_atime_nsec;
  long st_mtime;
  unsigned long st_mtime_nsec;
  long st_ctime;
  unsigned long st_ctime_nsec;
  unsigned long st_blksize;
  unsigned long st_pad2;
  long long st_blocks;
};
#endif
#if _MIPS_SIM == _MIPS_SIM_ABI64
struct stat {
  unsigned int st_dev;
  unsigned int st_pad0[3];
  unsigned long st_ino;
  mode_t st_mode;
  __u32 st_nlink;
  uid_t st_uid;
  gid_t st_gid;
  unsigned int st_rdev;
  unsigned int st_pad1[3];
  long st_size;
  unsigned int st_atime;
  unsigned int st_atime_nsec;
  unsigned int st_mtime;
  unsigned int st_mtime_nsec;
  unsigned int st_ctime;
  unsigned int st_ctime_nsec;
  unsigned int st_blksize;
  unsigned int st_pad2;
  unsigned long st_blocks;
};
#endif
#define STAT_HAVE_NSEC 1
#endif