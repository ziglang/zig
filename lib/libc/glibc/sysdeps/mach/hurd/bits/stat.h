/* Copyright (C) 1992-2020 Free Software Foundation, Inc.
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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#if !defined _SYS_STAT_H && !defined _FCNTL_H
# error "Never include <bits/stat.h> directly; use <sys/stat.h> instead."
#endif

#ifndef _BITS_STAT_H
#define _BITS_STAT_H	1

#include <bits/types.h>

/* NOTE: The size of this structure (32 ints) is known in
   <hurd/hurd_types.defs>, since it is used in the `io_stat' RPC.  MiG
   does not cope at all well with the passed C structure not being of
   the expected size.  There are some filler words at the end to allow
   for future expansion.  To increase the size of the structure used
   in the RPC and retain binary compatibility, we would need to assign
   a new message number.  */

struct stat
  {
    int st_fstype;		/* File system type.  */
    __fsid_t st_fsid;		/* File system ID.  */
#define	st_dev	st_fsid

#ifndef __USE_FILE_OFFSET64
    __ino_t st_ino;		/* File number.  */
#else
    __ino64_t st_ino;		/* File number.  */
#endif
    unsigned int st_gen;	/* To detect reuse of file numbers.  */
    __dev_t st_rdev;		/* Device if special file.  */
    __mode_t st_mode;		/* File mode.  */
    __nlink_t st_nlink;		/* Number of links.  */

    __uid_t st_uid;		/* Owner.  */
    __gid_t st_gid;		/* Owning group.  */

#ifndef __USE_FILE_OFFSET64
    __off_t st_size;		/* Size in bytes.  */
#else
    __off64_t st_size;		/* Size in bytes.  */
#endif

#ifdef __USE_XOPEN2K8
    /* Nanosecond resolution timestamps are stored in a format
       equivalent to 'struct timespec'.  This is the type used
       whenever possible but the Unix namespace rules do not allow the
       identifier 'timespec' to appear in the <sys/stat.h> header.
       Therefore we have to handle the use of this header in strictly
       standard-compliant sources special.  */
    struct timespec st_atim;		/* Time of last access.  */
    struct timespec st_mtim;		/* Time of last modification.  */
    struct timespec st_ctim;		/* Time of last status change.  */
# define st_atime st_atim.tv_sec	/* Backward compatibility.  */
# define st_mtime st_mtim.tv_sec
# define st_ctime st_ctim.tv_sec
#else
    __time_t st_atime;			/* Time of last access.  */
    unsigned long int st_atimensec;	/* Nscecs of last access.  */
    __time_t st_mtime;			/* Time of last modification.  */
    unsigned long int st_mtimensec;	/* Nsecs of last modification.  */
    __time_t st_ctime;			/* Time of last status change.  */
    unsigned long int st_ctimensec;	/* Nsecs of last status change.  */
#endif

    __blksize_t st_blksize;	/* Optimal size for I/O.  */

#ifndef __USE_FILE_OFFSET64
    __blkcnt_t st_blocks;	/* Number of 512-byte blocks allocated.
				   Not related to `st_blksize'.  */
#else
    __blkcnt64_t st_blocks;	/* Number of 512-byte blocks allocated.
				   Not related to `st_blksize'.  */
#endif

    __uid_t st_author;		/* File author.  */

    unsigned int st_flags;	/* User-defined flags.
				   High 16 bits can be set only by root.  */

#ifndef __USE_FILE_OFFSET64
# define _SPARE_SIZE	((sizeof (__fsid_t) == sizeof (int)) ? 12 : 11)
#else
# define _SPARE_SIZE	((sizeof (__fsid_t) == sizeof (int)) ? 9 : 8)
#endif
    int st_spare[_SPARE_SIZE];	/* Room for future expansion.  */
#undef _SPARE_SIZE
  };

#ifdef __USE_LARGEFILE64
struct stat64
  {
    int st_fstype;		/* File system type.  */
    __fsid_t st_fsid;		/* File system ID.  */
# define st_dev	st_fsid

    __ino64_t st_ino;		/* File number.  */
    unsigned int st_gen;	/* To detect reuse of file numbers.  */
    __dev_t st_rdev;		/* Device if special file.  */
    __mode_t st_mode;		/* File mode.  */
    __nlink_t st_nlink;		/* Number of links.  */

    __uid_t st_uid;		/* Owner.  */
    __gid_t st_gid;		/* Owning group.  */

    __off64_t st_size;		/* Size in bytes.  */

#ifdef __USE_XOPEN2K8
    /* Nanosecond resolution timestamps are stored in a format
       equivalent to 'struct timespec'.  This is the type used
       whenever possible but the Unix namespace rules do not allow the
       identifier 'timespec' to appear in the <sys/stat.h> header.
       Therefore we have to handle the use of this header in strictly
       standard-compliant sources special.  */
    struct timespec st_atim;		/* Time of last access.  */
    struct timespec st_mtim;		/* Time of last modification.  */
    struct timespec st_ctim;		/* Time of last status change.  */
#else
    __time_t st_atime;			/* Time of last access.  */
    unsigned long int st_atimensec;	/* Nscecs of last access.  */
    __time_t st_mtime;			/* Time of last modification.  */
    unsigned long int st_mtimensec;	/* Nsecs of last modification.  */
    __time_t st_ctime;			/* Time of last status change.  */
    unsigned long int st_ctimensec;	/* Nsecs of last status change.  */
#endif

    __blksize_t st_blksize;	/* Optimal size for I/O.  */

    __blkcnt64_t st_blocks;	/* Number of 512-byte blocks allocated.
				   Not related to `st_blksize'.  */

    __uid_t st_author;		/* File author.  */

    unsigned int st_flags;	/* User-defined flags.
				   High 16 bits can be set only by root.  */

#define _SPARE_SIZE	((sizeof (__fsid_t) == sizeof (int)) ? 9 : 8)
    int st_spare[_SPARE_SIZE];	/* Room for future expansion.  */
#undef _SPARE_SIZE
  };
#endif

/* Tell code we have these members.  */
#define	_STATBUF_ST_BLKSIZE
/* Nanosecond resolution time values are supported.  */
#define _STATBUF_ST_NSEC

/* Encoding of the file mode.  */

#define	__S_IFMT	0170000	/* These bits determine file type.  */

/* File types.  */
#define	__S_IFDIR	0040000	/* Directory.  */
#define	__S_IFCHR	0020000	/* Character device.  */
#define	__S_IFBLK	0060000	/* Block device.  */
#define	__S_IFREG	0100000	/* Regular file.  */
#define	__S_IFLNK	0120000	/* Symbolic link.  */
#define	__S_IFSOCK	0140000	/* Socket.  */
#define	__S_IFIFO	0010000	/* FIFO.  */

/* POSIX.1b objects.  */
#define __S_TYPEISMQ(buf) (0)
#define __S_TYPEISSEM(buf) (0)
#define __S_TYPEISSHM(buf) (0)

/* Protection bits.  */

#define	__S_ISUID	04000	/* Set user ID on execution.  */
#define	__S_ISGID	02000	/* Set group ID on execution.  */
#define	__S_ISVTX	01000	/* Save swapped text after use (sticky).  */
#define	__S_IREAD	00400	/* Read by owner.  */
#define	__S_IWRITE	00200	/* Write by owner.  */
#define	__S_IEXEC	00100	/* Execute by owner.  */


#ifdef	__USE_GNU
/* If set, there is no benefit in caching the contents of this file.  */
#define S_INOCACHE	000000200000

/* If the S_IUSEUNK bit is set, then the S_IUNKNOWN bits (see below)
   control access for unknown users.  If S_IUSEUNK is clear, then unknown
   users are treated as "others" for purposes of access control.  */
#define S_IUSEUNK	000000400000
/* Mask of protection bits for unknown users (no effective IDs at all).  */
#define S_IUNKNOWN      000007000000
/* Shift S_IREAD, S_IWRITE, S_IEXEC left this many bits to produce the
   protection bits for unknown users.  */
#define S_IUNKSHIFT	12

/* Read only bits: */

/* There is a passive translator set for this file */
#define S_IPTRANS	000010000000
/* There is an active translator running on this file */
#define S_IATRANS	000020000000
/* This is the root of a filesystem (or single node translator) */
#define S_IROOT		000040000000
/* All the bits relevant to translators */
#define S_ITRANS	000070000000

/* Definitely no mmaps to this.  */
#define S_IMMAP0	000100000000

/* ALL the unused bits.  */
#define	S_ISPARE	(~(S_IFMT|S_ITRANS|S_INOCACHE|S_IMMAP0    \
			   |S_IUSEUNK|S_IUNKNOWN|07777))
#endif

#ifdef	__USE_MISC
/* Default file creation mask (umask).  */
# define CMASK		0022

/* Definitions of flags stored in file flags word.  */

/* Super-user and owner changeable flags.  */
# define UF_SETTABLE	0x0000ffff	/* mask of owner changeable flags */
# define UF_NODUMP	0x00000001	/* do not dump file */
# define UF_IMMUTABLE	0x00000002	/* file may not be changed */
# define UF_APPEND	0x00000004	/* writes to file may only append */
# define UF_OPAQUE	0x00000008	/* directory is opaque wrt. union */
# define UF_NOUNLINK	0x00000010	/* file may not be removed or renamed */

/* Super-user changeable flags.  */
# define SF_SETTABLE	0xffff0000	/* mask of superuser changeable flags */
# define SF_ARCHIVED	0x00010000	/* file is archived */
# define SF_IMMUTABLE	0x00020000	/* file may not be changed */
# define SF_APPEND	0x00040000	/* writes to file may only append */
# define SF_NOUNLINK	0x00100000	/* file may not be removed or renamed */
# define SF_SNAPSHOT	0x00200000	/* snapshot inode */

__BEGIN_DECLS

/* Set file flags for FILE to FLAGS.  */
extern int chflags (__const char *__file, unsigned long int __flags) __THROW;

/* Set file flags of the file referred to by FD to FLAGS.  */
extern int fchflags (int __fd, unsigned long int __flags) __THROW;

__END_DECLS
#endif

#ifdef __USE_ATFILE
# define UTIME_NOW  -1 /* corresponds to the current time */
# define UTIME_OMIT -2 /* target time is omitted */
#endif

#endif	/* bits/stat.h */
