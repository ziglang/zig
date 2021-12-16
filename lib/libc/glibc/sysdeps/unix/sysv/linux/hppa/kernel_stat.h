/* definition of "struct stat" from the kernel */
struct kernel_stat {
	unsigned long	st_dev;		/* dev_t is 32 bits on parisc */
	unsigned long	st_ino;		/* 32 bits */
	unsigned short	st_mode;	/* 16 bits */
	unsigned short	st_nlink;	/* 16 bits */
	unsigned short	st_reserved1;	/* old st_uid */
	unsigned short	st_reserved2;	/* old st_gid */
	unsigned long	st_rdev;
	unsigned long   st_size;
	struct timespec st_atim;
	struct timespec st_mtim;
	struct timespec st_ctim;
	long		st_blksize;
	long		st_blocks;
	unsigned long	__glibc_reserved1;	/* ACL stuff */
	unsigned long	__glibc_reserved2;	/* network */
	unsigned long	__glibc_reserved3;	/* network */
	unsigned long	__glibc_reserved4;	/* cnodes */
	unsigned short	__glibc_reserved5;	/* netsite */
	short		st_fstype;
	unsigned long	st_realdev;
	unsigned short	st_basemode;
	unsigned short	st_spareshort;
	unsigned long	st_uid;
	unsigned long   st_gid;
	unsigned long	st_spare4[3];
};

#define _HAVE_STAT_NSEC
#define _HAVE_STAT64_NSEC

#define STAT_IS_KERNEL_STAT 0
#define STAT64_IS_KERNEL_STAT64 1
#define XSTAT_IS_XSTAT64 0
#define STATFS_IS_STATFS64 0
