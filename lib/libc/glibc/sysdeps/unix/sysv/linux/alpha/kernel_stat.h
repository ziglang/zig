/* Definition of `struct stat' used in the kernel.  */
struct kernel_stat
  {
    unsigned int st_dev;
    unsigned int st_ino;
    unsigned int st_mode;
    unsigned int st_nlink;
    unsigned int st_uid;
    unsigned int st_gid;
    unsigned int st_rdev;
    long int st_size;
    unsigned long int st_atime_sec;
    unsigned long int st_mtime_sec;
    unsigned long int st_ctime_sec;
    unsigned int st_blksize;
    int st_blocks;
    unsigned int st_flags;
    unsigned int st_gen;
  };

/* Definition of `struct stat64' used in the kernel.  */
struct kernel_stat64
  {
    unsigned long   st_dev;
    unsigned long   st_ino;
    unsigned long   st_rdev;
    long            st_size;
    unsigned long   st_blocks;

    unsigned int    st_mode;
    unsigned int    st_uid;
    unsigned int    st_gid;
    unsigned int    st_blksize;
    unsigned int    st_nlink;
    unsigned int    __pad0;

    unsigned long   st_atime_sec;
    unsigned long   st_atimensec;
    unsigned long   st_mtime_sec;
    unsigned long   st_mtimensec;
    unsigned long   st_ctime_sec;
    unsigned long   st_ctimensec;
    long            __glibc_reserved[3];
  };

/* Definition of `struct stat' used by glibc 2.0.  */
struct glibc2_stat
  {
    __dev_t st_dev;
    __ino_t st_ino;
    __mode_t st_mode;
    __nlink_t st_nlink;
    __uid_t st_uid;
    __gid_t st_gid;
    __dev_t st_rdev;
    __off_t st_size;
    __time_t st_atime_sec;
    __time_t st_mtime_sec;
    __time_t st_ctime_sec;
    unsigned int st_blksize;
    int st_blocks;
    unsigned int st_flags;
    unsigned int st_gen;
  };

/* Definition of `struct stat' used by glibc 2.1.  */
struct glibc21_stat
  {
    __dev_t st_dev;
    __ino64_t st_ino;
    __mode_t st_mode;
    __nlink_t st_nlink;
    __uid_t st_uid;
    __gid_t st_gid;
    __dev_t st_rdev;
    __off_t st_size;
    __time_t st_atime_sec;
    __time_t st_mtime_sec;
    __time_t st_ctime_sec;
    __blkcnt64_t st_blocks;
    __blksize_t st_blksize;
    unsigned int st_flags;
    unsigned int st_gen;
    int __pad3;
    long __glibc_reserved[4];
  };

#define STAT_IS_KERNEL_STAT 0
#define STAT64_IS_KERNEL_STAT64 1
#define XSTAT_IS_XSTAT64 1
#define STATFS_IS_STATFS64 0
