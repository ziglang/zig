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
#ifndef __ASM_GENERIC_STAT_H
#define __ASM_GENERIC_STAT_H
#include <asm/bitsperlong.h>
#define STAT_HAVE_NSEC 1
struct stat {
  unsigned long st_dev;
  unsigned long st_ino;
  unsigned int st_mode;
  unsigned int st_nlink;
  unsigned int st_uid;
  unsigned int st_gid;
  unsigned long st_rdev;
  unsigned long __pad1;
  long st_size;
  int st_blksize;
  int __pad2;
  long st_blocks;
  long st_atime;
  unsigned long st_atime_nsec;
  long st_mtime;
  unsigned long st_mtime_nsec;
  long st_ctime;
  unsigned long st_ctime_nsec;
  unsigned int __unused4;
  unsigned int __unused5;
};
#if __BITS_PER_LONG != 64 || defined(__ARCH_WANT_STAT64)
struct stat64 {
  unsigned long long st_dev;
  unsigned long long st_ino;
  unsigned int st_mode;
  unsigned int st_nlink;
  unsigned int st_uid;
  unsigned int st_gid;
  unsigned long long st_rdev;
  unsigned long long __pad1;
  long long st_size;
  int st_blksize;
  int __pad2;
  long long st_blocks;
  int st_atime;
  unsigned int st_atime_nsec;
  int st_mtime;
  unsigned int st_mtime_nsec;
  int st_ctime;
  unsigned int st_ctime_nsec;
  unsigned int __unused4;
  unsigned int __unused5;
};
#endif
#endif