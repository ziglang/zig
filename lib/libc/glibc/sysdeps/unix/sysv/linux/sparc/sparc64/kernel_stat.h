#ifndef _KERNEL_STAT_H
#define _KERNEL_STAT_H

/* Definition of `struct stat' used in the kernel */
struct kernel_stat
  {
    unsigned int st_dev;
    unsigned long int st_ino;
    unsigned int st_mode;
    short int st_nlink;
    unsigned int st_uid;
    unsigned int st_gid;
    unsigned int st_rdev;
    long int st_size;
    long int st_atime_sec;
    long int st_mtime_sec;
    long int st_ctime_sec;
    long int st_blksize;
    long int st_blocks;
    unsigned long int __glibc_reserved1;
    unsigned long int __glibc_reserved2;
  };

/* Definition of `struct stat64' used in the kernel.  */
struct kernel_stat64
  {
    unsigned long int st_dev;
    unsigned long int st_ino;
    unsigned long int st_nlink;

    unsigned int st_mode;
    unsigned int st_uid;
    unsigned int st_gid;
    unsigned int __pad0;

    unsigned long int st_rdev;
    long int st_size;
    long int st_blksize;
    long int st_blocks;

    unsigned long int st_atime_sec;
    unsigned long int st_atime_nsec;
    unsigned long int st_mtime_sec;
    unsigned long int st_mtime_nsec;
    unsigned long int st_ctime_sec;
    unsigned long int st_ctime_nsec;
    long int __glibc_reserved[3];
  };

#define STAT_IS_KERNEL_STAT 0
#define STAT64_IS_KERNEL_STAT64 0
#define XSTAT_IS_XSTAT64 1
#ifdef __arch64__
# define STATFS_IS_STATFS64 1
#else
# define STATFS_IS_STATFS64 0
#endif
#endif /* _KERNEL_STAT_H  */
