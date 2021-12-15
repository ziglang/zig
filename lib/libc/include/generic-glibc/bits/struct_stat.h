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

#include <sgidefs.h>

#if _MIPS_SIM == _ABIO32
/* Structure describing file characteristics.  */
struct stat
  {
# ifdef __USE_TIME_BITS64
#  include <bits/struct_stat_time64_helper.h>
# else
    unsigned long int st_dev;
    long int st_pad1[3];
#  ifndef __USE_FILE_OFFSET64
    __ino_t st_ino;		/* File serial number.		*/
#  else
    __ino64_t st_ino;		/* File serial number.		*/
#  endif
    __mode_t st_mode;		/* File mode.  */
    __nlink_t st_nlink;		/* Link count.  */
    __uid_t st_uid;		/* User ID of the file's owner.	*/
    __gid_t st_gid;		/* Group ID of the file's group.*/
    unsigned long int st_rdev;	/* Device number, if device.  */
#  ifndef __USE_FILE_OFFSET64
    long int st_pad2[2];
    __off_t st_size;		/* Size of file, in bytes.  */
    /* SVR4 added this extra long to allow for expansion of off_t.  */
    long int st_pad3;
#  else
    long int st_pad2[3];
    __off64_t st_size;		/* Size of file, in bytes.  */
#  endif
#  ifdef __USE_XOPEN2K8
    /* Nanosecond resolution timestamps are stored in a format
       equivalent to 'struct timespec'.  This is the type used
       whenever possible but the Unix namespace rules do not allow the
       identifier 'timespec' to appear in the <sys/stat.h> header.
       Therefore we have to handle the use of this header in strictly
       standard-compliant sources special.  */
    struct timespec st_atim;            /* Time of last access.  */
    struct timespec st_mtim;            /* Time of last modification.  */
    struct timespec st_ctim;            /* Time of last status change.  */
#   define st_atime st_atim.tv_sec        /* Backward compatibility.  */
#   define st_mtime st_mtim.tv_sec
#   define st_ctime st_ctim.tv_sec
#  else
    __time_t st_atime;			/* Time of last access.  */
    unsigned long int st_atimensec;	/* Nscecs of last access.  */
    __time_t st_mtime;			/* Time of last modification.  */
    unsigned long int st_mtimensec;	/* Nsecs of last modification.  */
    __time_t st_ctime;			/* Time of last status change.  */
    unsigned long int st_ctimensec;	/* Nsecs of last status change.  */
#  endif
    __blksize_t st_blksize;	/* Optimal block size for I/O.  */
#  ifndef __USE_FILE_OFFSET64
    __blkcnt_t st_blocks;	/* Number of 512-byte blocks allocated.  */
#  else
    long int st_pad4;
    __blkcnt64_t st_blocks;	/* Number of 512-byte blocks allocated.  */
#  endif
    long int st_pad5[14];
# endif /* __USE_TIME_BITS64  */
  };

# ifdef __USE_LARGEFILE64
struct stat64
  {
#  ifdef __USE_TIME_BITS64
#   include <bits/struct_stat_time64_helper.h>
#  else
    unsigned long int st_dev;
    long int st_pad1[3];
    __ino64_t st_ino;		/* File serial number.		*/
    __mode_t st_mode;		/* File mode.  */
    __nlink_t st_nlink;		/* Link count.  */
    __uid_t st_uid;		/* User ID of the file's owner.	*/
    __gid_t st_gid;		/* Group ID of the file's group.*/
    unsigned long int st_rdev;	/* Device number, if device.  */
    long int st_pad2[3];
    __off64_t st_size;		/* Size of file, in bytes.  */
#   ifdef __USE_XOPEN2K8
    /* Nanosecond resolution timestamps are stored in a format
       equivalent to 'struct timespec'.  This is the type used
       whenever possible but the Unix namespace rules do not allow the
       identifier 'timespec' to appear in the <sys/stat.h> header.
       Therefore we have to handle the use of this header in strictly
       standard-compliant sources special.  */
    struct timespec st_atim;            /* Time of last access.  */
    struct timespec st_mtim;            /* Time of last modification.  */
    struct timespec st_ctim;            /* Time of last status change.  */
#   else
    __time_t st_atime;			/* Time of last access.  */
    unsigned long int st_atimensec;	/* Nscecs of last access.  */
    __time_t st_mtime;			/* Time of last modification.  */
    unsigned long int st_mtimensec;	/* Nsecs of last modification.  */
    __time_t st_ctime;			/* Time of last status change.  */
    unsigned long int st_ctimensec;	/* Nsecs of last status change.  */
#   endif
    __blksize_t st_blksize;	/* Optimal block size for I/O.  */
    long int st_pad3;
    __blkcnt64_t st_blocks;	/* Number of 512-byte blocks allocated.  */
    long int st_pad4[14];
#  endif /* __USE_TIME_BITS64  */
  };
# endif /* __USE_LARGEFILE64  */

#else /* _MIPS_SIM != _ABIO32  */

struct stat
  {
    __dev_t st_dev;
    int	st_pad1[3];		/* Reserved for st_dev expansion  */
# ifndef __USE_FILE_OFFSET64
    __ino_t st_ino;
# else
    __ino64_t st_ino;
# endif
    __mode_t st_mode;
    __nlink_t st_nlink;
    __uid_t st_uid;
    __gid_t st_gid;
    __dev_t st_rdev;
# if !defined __USE_FILE_OFFSET64
    unsigned int st_pad2[2];	/* Reserved for st_rdev expansion  */
    __off_t st_size;
    int st_pad3;
# else
    unsigned int st_pad2[3];	/* Reserved for st_rdev expansion  */
    __off64_t st_size;
# endif
# ifdef __USE_XOPEN2K8
    /* Nanosecond resolution timestamps are stored in a format
       equivalent to 'struct timespec'.  This is the type used
       whenever possible but the Unix namespace rules do not allow the
       identifier 'timespec' to appear in the <sys/stat.h> header.
       Therefore we have to handle the use of this header in strictly
       standard-compliant sources special.  */
    struct timespec st_atim;            /* Time of last access.  */
    struct timespec st_mtim;            /* Time of last modification.  */
    struct timespec st_ctim;            /* Time of last status change.  */
#  define st_atime st_atim.tv_sec        /* Backward compatibility.  */
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
    __blksize_t st_blksize;
    unsigned int st_pad4;
# ifndef __USE_FILE_OFFSET64
    __blkcnt_t st_blocks;
# else
    __blkcnt64_t st_blocks;
# endif
    int st_pad5[14];
  };

#ifdef __USE_LARGEFILE64
struct stat64
  {
    __dev_t st_dev;
    unsigned int st_pad1[3];	/* Reserved for st_dev expansion  */
    __ino64_t st_ino;
    __mode_t st_mode;
    __nlink_t st_nlink;
    __uid_t st_uid;
    __gid_t st_gid;
    __dev_t st_rdev;
    unsigned int st_pad2[3];	/* Reserved for st_rdev expansion  */
    __off64_t st_size;
#  ifdef __USE_XOPEN2K8
    /* Nanosecond resolution timestamps are stored in a format
       equivalent to 'struct timespec'.  This is the type used
       whenever possible but the Unix namespace rules do not allow the
       identifier 'timespec' to appear in the <sys/stat.h> header.
       Therefore we have to handle the use of this header in strictly
       standard-compliant sources special.  */
    struct timespec st_atim;            /* Time of last access.  */
    struct timespec st_mtim;            /* Time of last modification.  */
    struct timespec st_ctim;            /* Time of last status change.  */
#  else
    __time_t st_atime;			/* Time of last access.  */
    unsigned long int st_atimensec;	/* Nscecs of last access.  */
    __time_t st_mtime;			/* Time of last modification.  */
    unsigned long int st_mtimensec;	/* Nsecs of last modification.  */
    __time_t st_ctime;			/* Time of last status change.  */
    unsigned long int st_ctimensec;	/* Nsecs of last status change.  */
#  endif
    __blksize_t st_blksize;
    unsigned int st_pad3;
    __blkcnt64_t st_blocks;
    int st_pad4[14];
};
#endif

#endif

/* Tell code we have these members.  */
#define	_STATBUF_ST_BLKSIZE
#define	_STATBUF_ST_RDEV

#endif /* _BITS_STRUCT_STAT_H  */