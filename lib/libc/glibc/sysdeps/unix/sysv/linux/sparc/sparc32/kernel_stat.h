/* Definition of `struct stat' used in the kernel */
struct kernel_stat
  {
    unsigned short int st_dev;
    unsigned long int st_ino;
    unsigned short int st_mode;
    short int st_nlink;
    unsigned short int st_uid;
    unsigned short int st_gid;
    unsigned short int st_rdev;
    long int st_size;
    struct timespec st_atim;
    struct timespec st_mtim;
    struct timespec st_ctim;
    long int st_blksize;
    long int st_blocks;
    unsigned long int __glibc_reserved4;
    unsigned long int __glibc_reserved5;
  };

#define _HAVE___UNUSED4
#define _HAVE___UNUSED5

#define _HAVE_STAT___UNUSED4
#define _HAVE_STAT___UNUSED5
#define _HAVE_STAT___PAD1
#define _HAVE_STAT___PAD2
#define _HAVE_STAT64___UNUSED4
#define _HAVE_STAT64___UNUSED5
#define _HAVE_STAT64___PAD2
#define _HAVE_STAT_NSEC
#define _HAVE_STAT64_NSEC

#define STAT_IS_KERNEL_STAT 0
#define STAT64_IS_KERNEL_STAT64 1
#define XSTAT_IS_XSTAT64 0
#define STATFS_IS_STATFS64 0
