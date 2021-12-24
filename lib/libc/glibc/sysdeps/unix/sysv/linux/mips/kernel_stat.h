#ifndef _KERNEL_STAT_H
#define _KERNEL_STAT_H

#include <sgidefs.h>
/* As tempting as it is to define XSTAT_IS_XSTAT64 for n64, the
   userland data structures are not identical, because of different
   padding.  */
/* Definition of `struct stat' used in the kernel.  */
#if _MIPS_SIM != _ABIO32
struct kernel_stat
  {
    unsigned int st_dev;
    unsigned int __pad1[3];
    unsigned long long st_ino;
    unsigned int st_mode;
    unsigned int st_nlink;
    int st_uid;
    int st_gid;
    unsigned int st_rdev;
    unsigned int __pad2[3];
    long long st_size;
    unsigned int st_atime_sec;
    unsigned int st_atime_nsec;
    unsigned int st_mtime_sec;
    unsigned int st_mtime_nsec;
    unsigned int st_ctime_sec;
    unsigned int st_ctime_nsec;
    unsigned int st_blksize;
    unsigned int __pad3;
    unsigned long long st_blocks;
  };
#else
struct kernel_stat
  {
    unsigned long int st_dev;
    long int __pad1[3];			/* Reserved for network id */
    unsigned long int st_ino;
    unsigned long int st_mode;
    unsigned long int st_nlink;
    long int st_uid;
    long int st_gid;
    unsigned long int st_rdev;
    long int __pad2[2];
    long int st_size;
    long int __pad3;
    unsigned int st_atime_sec;
    unsigned int st_atime_nsec;
    unsigned int st_mtime_sec;
    unsigned int st_mtime_nsec;
    unsigned int st_ctime_sec;
    unsigned int st_ctime_nsec;
    long int st_blksize;
    long int st_blocks;
    char st_fstype[16];			/* Filesystem type name, unsupported */
    long st_pad4[8];
    /* Linux specific fields */
    unsigned int st_flags;
    unsigned int st_gen;
  };
#endif

#define STAT_IS_KERNEL_STAT 0
#define STAT64_IS_KERNEL_STAT64 0
#define XSTAT_IS_XSTAT64 0
#if _MIPS_SIM == _ABI64
# define STATFS_IS_STATFS64 1
#else
# define STATFS_IS_STATFS64 0
#endif
/* MIPS64 has unsigned 32 bit timestamps fields, so use statx as well.  */
#if _MIPS_SIM == _ABI64
# define STAT_HAS_TIME32
#endif

#endif
