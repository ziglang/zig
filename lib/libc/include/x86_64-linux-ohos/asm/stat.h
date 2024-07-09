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
#ifndef _ASM_X86_STAT_H
#define _ASM_X86_STAT_H
#include <asm/posix_types.h>
#define STAT_HAVE_NSEC 1
#ifdef __i386__
struct stat {
  unsigned long st_dev;
  unsigned long st_ino;
  unsigned short st_mode;
  unsigned short st_nlink;
  unsigned short st_uid;
  unsigned short st_gid;
  unsigned long st_rdev;
  unsigned long st_size;
  unsigned long st_blksize;
  unsigned long st_blocks;
  unsigned long st_atime;
  unsigned long st_atime_nsec;
  unsigned long st_mtime;
  unsigned long st_mtime_nsec;
  unsigned long st_ctime;
  unsigned long st_ctime_nsec;
  unsigned long __unused4;
  unsigned long __unused5;
};
#define INIT_STRUCT_STAT_PADDING(st) do { st.__unused4 = 0; st.__unused5 = 0; \
} while(0)
#define STAT64_HAS_BROKEN_ST_INO 1
struct stat64 {
  unsigned long long st_dev;
  unsigned char __pad0[4];
  unsigned long __st_ino;
  unsigned int st_mode;
  unsigned int st_nlink;
  unsigned long st_uid;
  unsigned long st_gid;
  unsigned long long st_rdev;
  unsigned char __pad3[4];
  long long st_size;
  unsigned long st_blksize;
  unsigned long long st_blocks;
  unsigned long st_atime;
  unsigned long st_atime_nsec;
  unsigned long st_mtime;
  unsigned int st_mtime_nsec;
  unsigned long st_ctime;
  unsigned long st_ctime_nsec;
  unsigned long long st_ino;
};
#define INIT_STRUCT_STAT64_PADDING(st) do { memset(& st.__pad0, 0, sizeof(st.__pad0)); memset(& st.__pad3, 0, sizeof(st.__pad3)); \
} while(0)
#else
struct stat {
  __kernel_ulong_t st_dev;
  __kernel_ulong_t st_ino;
  __kernel_ulong_t st_nlink;
  unsigned int st_mode;
  unsigned int st_uid;
  unsigned int st_gid;
  unsigned int __pad0;
  __kernel_ulong_t st_rdev;
  __kernel_long_t st_size;
  __kernel_long_t st_blksize;
  __kernel_long_t st_blocks;
  __kernel_ulong_t st_atime;
  __kernel_ulong_t st_atime_nsec;
  __kernel_ulong_t st_mtime;
  __kernel_ulong_t st_mtime_nsec;
  __kernel_ulong_t st_ctime;
  __kernel_ulong_t st_ctime_nsec;
  __kernel_long_t __linux_unused[3];
};
#define INIT_STRUCT_STAT_PADDING(st) do { st.__pad0 = 0; st.__linux_unused[0] = 0; st.__linux_unused[1] = 0; st.__linux_unused[2] = 0; \
} while(0)
#endif
struct __old_kernel_stat {
  unsigned short st_dev;
  unsigned short st_ino;
  unsigned short st_mode;
  unsigned short st_nlink;
  unsigned short st_uid;
  unsigned short st_gid;
  unsigned short st_rdev;
#ifdef __i386__
  unsigned long st_size;
  unsigned long st_atime;
  unsigned long st_mtime;
  unsigned long st_ctime;
#else
  unsigned int st_size;
  unsigned int st_atime;
  unsigned int st_mtime;
  unsigned int st_ctime;
#endif
};
#endif
