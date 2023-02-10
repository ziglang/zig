/* Definition for struct stat.
   Copyright (C) 2020-2021 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#if !defined _SYS_STAT_H && !defined _FCNTL_H
# error "Never include <bits/struct_stat.h> directly; use <sys/stat.h> instead."
#endif

#ifndef _BITS_STRUCT_STAT_H
#define _BITS_STRUCT_STAT_H	1

struct stat
  {
#ifdef __USE_TIME_BITS64
# include <bits/struct_stat_time64_helper.h>
#else
    __dev_t st_dev;		/* Device.  */
# ifndef __x86_64__
    unsigned short int __pad1;
# endif
# if defined __x86_64__ || !defined __USE_FILE_OFFSET64
    __ino_t st_ino;		/* File serial number.	*/
# else
    __ino_t __st_ino;			/* 32bit file serial number.	*/
# endif
# ifndef __x86_64__
    __mode_t st_mode;			/* File mode.  */
    __nlink_t st_nlink;			/* Link count.  */
# else
    __nlink_t st_nlink;		/* Link count.  */
    __mode_t st_mode;		/* File mode.  */
# endif
    __uid_t st_uid;		/* User ID of the file's owner.	*/
    __gid_t st_gid;		/* Group ID of the file's group.*/
# ifdef __x86_64__
    int __pad0;
# endif
    __dev_t st_rdev;		/* Device number, if device.  */
# ifndef __x86_64__
    unsigned short int __pad2;
# endif
# if defined __x86_64__ || !defined __USE_FILE_OFFSET64
    __off_t st_size;			/* Size of file, in bytes.  */
# else
    __off64_t st_size;			/* Size of file, in bytes.  */
# endif
    __blksize_t st_blksize;	/* Optimal block size for I/O.  */
# if defined __x86_64__  || !defined __USE_FILE_OFFSET64
    __blkcnt_t st_blocks;		/* Number 512-byte blocks allocated. */
# else
    __blkcnt64_t st_blocks;		/* Number 512-byte blocks allocated. */
# endif
# ifdef __USE_XOPEN2K8
    /* Nanosecond resolution timestamps are stored in a format
       equivalent to 'struct timespec'.  This is the type used
       whenever possible but the Unix namespace rules do not allow the
       identifier 'timespec' to appear in the <sys/stat.h> header.
       Therefore we have to handle the use of this header in strictly
       standard-compliant sources special.  */
    struct timespec st_atim;		/* Time of last access.  */
    struct timespec st_mtim;		/* Time of last modification.  */
    struct timespec st_ctim;		/* Time of last status change.  */
#  define st_atime st_atim.tv_sec	/* Backward compatibility.  */
#  define st_mtime st_mtim.tv_sec
#  define st_ctime st_ctim.tv_sec
# else
    __time_t st_atime;			/* Time of last access.  */
    __syscall_ulong_t st_atimensec;	/* Nscecs of last access.  */
    __time_t st_mtime;			/* Time of last modification.  */
    __syscall_ulong_t st_mtimensec;	/* Nsecs of last modification.  */
    __time_t st_ctime;			/* Time of last status change.  */
    __syscall_ulong_t st_ctimensec;	/* Nsecs of last status change.  */
# endif
# ifdef __x86_64__
    __syscall_slong_t __glibc_reserved[3];
# else
#  ifndef __USE_FILE_OFFSET64
    unsigned long int __glibc_reserved4;
    unsigned long int __glibc_reserved5;
#  else
    __ino64_t st_ino;			/* File serial number.	*/
#  endif
# endif
#endif /* __USE_TIME_BITS64  */
  };

#ifdef __USE_LARGEFILE64
/* Note stat64 has the same shape as stat for x86-64.  */
struct stat64
  {
# ifdef __USE_TIME_BITS64
#  include <bits/struct_stat_time64_helper.h>
# else
    __dev_t st_dev;		/* Device.  */
#  ifdef __x86_64__
    __ino64_t st_ino;		/* File serial number.  */
    __nlink_t st_nlink;		/* Link count.  */
    __mode_t st_mode;		/* File mode.  */
#  else
    unsigned int __pad1;
    __ino_t __st_ino;			/* 32bit file serial number.	*/
    __mode_t st_mode;			/* File mode.  */
    __nlink_t st_nlink;			/* Link count.  */
#  endif
    __uid_t st_uid;		/* User ID of the file's owner.	*/
    __gid_t st_gid;		/* Group ID of the file's group.*/
#  ifdef __x86_64__
    int __pad0;
    __dev_t st_rdev;		/* Device number, if device.  */
    __off_t st_size;		/* Size of file, in bytes.  */
#  else
    __dev_t st_rdev;			/* Device number, if device.  */
    unsigned int __pad2;
    __off64_t st_size;			/* Size of file, in bytes.  */
#  endif
    __blksize_t st_blksize;	/* Optimal block size for I/O.  */
    __blkcnt64_t st_blocks;	/* Nr. 512-byte blocks allocated.  */
#  ifdef __USE_XOPEN2K8
    /* Nanosecond resolution timestamps are stored in a format
       equivalent to 'struct timespec'.  This is the type used
       whenever possible but the Unix namespace rules do not allow the
       identifier 'timespec' to appear in the <sys/stat.h> header.
       Therefore we have to handle the use of this header in strictly
       standard-compliant sources special.  */
    struct timespec st_atim;		/* Time of last access.  */
    struct timespec st_mtim;		/* Time of last modification.  */
    struct timespec st_ctim;		/* Time of last status change.  */
#  else
    __time_t st_atime;			/* Time of last access.  */
    __syscall_ulong_t st_atimensec;	/* Nscecs of last access.  */
    __time_t st_mtime;			/* Time of last modification.  */
    __syscall_ulong_t st_mtimensec;	/* Nsecs of last modification.  */
    __time_t st_ctime;			/* Time of last status change.  */
    __syscall_ulong_t st_ctimensec;	/* Nsecs of last status change.  */
#  endif
#  ifdef __x86_64__
    __syscall_slong_t __glibc_reserved[3];
#  else
    __ino64_t st_ino;			/* File serial number.		*/
#  endif
# endif /* __USE_TIME_BITS64  */
  };
#endif

/* Tell code we have these members.  */
#define	_STATBUF_ST_BLKSIZE
#define _STATBUF_ST_RDEV
/* Nanosecond resolution time values are supported.  */
#define _STATBUF_ST_NSEC

#endif /* _BITS_STRUCT_STAT_H  */