/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef __SPARC_STAT_H
#define __SPARC_STAT_H

#include <linux/types.h>

#if defined(__sparc__) && defined(__arch64__)
/* 64 bit sparc */
struct stat {
	unsigned int st_dev;
	__kernel_ino_t st_ino;
	__kernel_mode_t st_mode;
	short   st_nlink;
	__kernel_uid32_t st_uid;
	__kernel_gid32_t st_gid;
	unsigned int st_rdev;
	long    st_size;
	long    st_atime;
	long    st_mtime;
	long    st_ctime;
	long    st_blksize;
	long    st_blocks;
	unsigned long  __unused4[2];
};

struct stat64 {
	unsigned long	st_dev;
	unsigned long	st_ino;
	unsigned long	st_nlink;

	unsigned int	st_mode;
	unsigned int	st_uid;
	unsigned int	st_gid;
	unsigned int	__pad0;

	unsigned long	st_rdev;
	long		st_size;
	long		st_blksize;
	long		st_blocks;

	unsigned long	st_atime;
	unsigned long	st_atime_nsec;
	unsigned long	st_mtime;
	unsigned long	st_mtime_nsec;
	unsigned long	st_ctime;
	unsigned long	st_ctime_nsec;
	long		__unused[3];
};

#else
/* 32 bit sparc */
struct stat {
	unsigned short	st_dev;
	__kernel_ino_t	st_ino;
	__kernel_mode_t	st_mode;
	short		st_nlink;
	unsigned short	st_uid;
	unsigned short	st_gid;
	unsigned short	st_rdev;
	long		st_size;
	long		st_atime;
	unsigned long	st_atime_nsec;
	long		st_mtime;
	unsigned long	st_mtime_nsec;
	long		st_ctime;
	unsigned long	st_ctime_nsec;
	long		st_blksize;
	long		st_blocks;
	unsigned long	__unused4[2];
};

#define STAT_HAVE_NSEC 1

struct stat64 {
	unsigned long long st_dev;

	unsigned long long st_ino;

	unsigned int	st_mode;
	unsigned int	st_nlink;

	unsigned int	st_uid;
	unsigned int	st_gid;

	unsigned long long st_rdev;

	unsigned char	__pad3[8];

	long long	st_size;
	unsigned int	st_blksize;

	unsigned char	__pad4[8];
	unsigned int	st_blocks;

	unsigned int	st_atime;
	unsigned int	st_atime_nsec;

	unsigned int	st_mtime;
	unsigned int	st_mtime_nsec;

	unsigned int	st_ctime;
	unsigned int	st_ctime_nsec;

	unsigned int	__unused4;
	unsigned int	__unused5;
};
#endif /* defined(__sparc__) && defined(__arch64__) */
#endif /* __SPARC_STAT_H */