/* Copyright (C) 1992-2025 Free Software Foundation, Inc.
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

#include <bits/struct_stat.h>

/* Encoding of the file mode.  */

#define	__S_IFMT	0170000	/* These bits determine file type.  */

/* File types.  */
#define	__S_IFDIR	0040000	/* Directory.  */
#define	__S_IFCHR	0020000	/* Character device.  */
#define	__S_IFBLK	0060000	/* Block device.  */
#define	__S_IFREG	0100000	/* Regular file.  */
#define	__S_IFIFO	0010000	/* FIFO.  */
#define	__S_IFLNK	0120000	/* Symbolic link.  */
#define	__S_IFSOCK	0140000	/* Socket.  */

/* POSIX.1b objects.  Note that these macros always evaluate to zero.  But
   they do it by enforcing the correct use of the macros.  */
#define __S_TYPEISMQ(buf)  ((buf)->st_mode - (buf)->st_mode)
#define __S_TYPEISSEM(buf) ((buf)->st_mode - (buf)->st_mode)
#define __S_TYPEISSHM(buf) ((buf)->st_mode - (buf)->st_mode)

/* Protection bits.  */

#define	__S_ISUID	04000	/* Set user ID on execution.  */
#define	__S_ISGID	02000	/* Set group ID on execution.  */
#define	__S_ISVTX	01000	/* Save swapped text after use (sticky).  */
#define	__S_IREAD	0400	/* Read by owner.  */
#define	__S_IWRITE	0200	/* Write by owner.  */
#define	__S_IEXEC	0100	/* Execute by owner.  */

#ifdef __USE_ATFILE
# define UTIME_NOW	((1l << 30) - 1l)
# define UTIME_OMIT	((1l << 30) - 2l)
#endif

#endif	/* bits/stat.h */
