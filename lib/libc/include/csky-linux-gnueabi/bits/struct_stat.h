/* Definition for struct stat.  Linux/csky version.
   Copyright (C) 2020-2024 Free Software Foundation, Inc.
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

#include <bits/endian.h>
#include <bits/wordsize.h>

#if defined __USE_FILE_OFFSET64
# define __field64(type, type64, name) type64 name
#elif __WORDSIZE == 64 || defined __INO_T_MATCHES_INO64_T
# if defined __INO_T_MATCHES_INO64_T && !defined __OFF_T_MATCHES_OFF64_T
#  error "ino_t and off_t must both be the same type"
# endif
# define __field64(type, type64, name) type name
#elif __BYTE_ORDER == __LITTLE_ENDIAN
# define __field64(type, type64, name) \
  type name __attribute__((__aligned__ (__alignof__ (type64)))); int __##name##_pad
#else
# define __field64(type, type64, name) \
  int __##name##_pad __attribute__((__aligned__ (__alignof__ (type64)))); type name
#endif

struct stat
  {
#ifdef __USE_TIME64_REDIRECTS
# include <bits/struct_stat_time64_helper.h>
#else
    __dev_t st_dev;		/* Device.  */
    __field64(__ino_t, __ino64_t, st_ino);  /* File serial number. */
    __mode_t st_mode;		/* File mode.  */
    __nlink_t st_nlink;		/* Link count.  */
    __uid_t st_uid;		/* User ID of the file's owner.	*/
    __gid_t st_gid;		/* Group ID of the file's group.*/
    __dev_t st_rdev;		/* Device number, if device.  */
    __dev_t __pad1;
    __field64(__off_t, __off64_t, st_size);  /* Size of file, in bytes. */
    __blksize_t st_blksize;	/* Optimal block size for I/O.  */
    int __pad2;
    __field64(__blkcnt_t, __blkcnt64_t, st_blocks);  /* 512-byte blocks */
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
    unsigned long int st_atimensec;	/* Nscecs of last access.  */
    __time_t st_mtime;			/* Time of last modification.  */
    unsigned long int st_mtimensec;	/* Nsecs of last modification.  */
    __time_t st_ctime;			/* Time of last status change.  */
    unsigned long int st_ctimensec;	/* Nsecs of last status change.  */
# endif
    int __glibc_reserved[2];
#endif
  };

#undef __field64

#ifdef __USE_LARGEFILE64
struct stat64
  {
# ifdef __USE_TIME64_REDIRECTS
#  include <bits/struct_stat_time64_helper.h>
# else
    __dev_t st_dev;		/* Device.  */
    __ino64_t st_ino;		/* File serial number.	*/
    __mode_t st_mode;		/* File mode.  */
    __nlink_t st_nlink;		/* Link count.  */
    __uid_t st_uid;		/* User ID of the file's owner.	*/
    __gid_t st_gid;		/* Group ID of the file's group.*/
    __dev_t st_rdev;		/* Device number, if device.  */
    __dev_t __pad1;
    __off64_t st_size;		/* Size of file, in bytes.  */
    __blksize_t st_blksize;	/* Optimal block size for I/O.  */
    int __pad2;
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
    unsigned long int st_atimensec;	/* Nscecs of last access.  */
    __time_t st_mtime;			/* Time of last modification.  */
    unsigned long int st_mtimensec;	/* Nsecs of last modification.  */
    __time_t st_ctime;			/* Time of last status change.  */
    unsigned long int st_ctimensec;	/* Nsecs of last status change.  */
#  endif
    int __glibc_reserved[2];
# endif
  };
#endif

/* Tell code we have these members.  */
#define	_STATBUF_ST_BLKSIZE
#define _STATBUF_ST_RDEV
/* Nanosecond resolution time values are supported.  */
#define _STATBUF_ST_NSEC

#endif /* _BITS_STRUCT_STAT_H  */