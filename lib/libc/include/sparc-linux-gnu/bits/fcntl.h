/* O_*, F_*, FD_* bit values for Linux/SPARC.
   Copyright (C) 1995-2024 Free Software Foundation, Inc.
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

#ifndef _FCNTL_H
# error "Never use <bits/fcntl.h> directly; include <fcntl.h> instead."
#endif

#include <bits/wordsize.h>

#define O_APPEND	0x0008
#define O_ASYNC		0x0040
#define O_CREAT		0x0200	/* not fcntl */
#define O_TRUNC		0x0400	/* not fcntl */
#define O_EXCL		0x0800	/* not fcntl */
#define O_SYNC		0x802000
#define O_NONBLOCK	0x4000
#define O_NDELAY	(0x0004 | O_NONBLOCK)
#define O_NOCTTY        0x8000  /* not fcntl */

#define __O_DIRECTORY	0x10000 /* must be a directory */
#define __O_NOFOLLOW	0x20000 /* don't follow links */
#define __O_CLOEXEC	0x400000 /* Set close_on_exit.  */

#define __O_DIRECT	0x100000 /* direct disk access hint */
#define __O_NOATIME	0x200000 /* Do not set atime.  */
#define __O_PATH	0x1000000 /* Resolve pathname but do not open file.  */
#define __O_TMPFILE	0x2010000 /* Atomically create nameless file.  */

#if __WORDSIZE == 64
# define __O_LARGEFILE	0
#else
# define __O_LARGEFILE	0x40000
#endif

#define __O_DSYNC	0x2000	/* Synchronize data.  */


#define __F_GETOWN	5	/* Get owner (process receiving SIGIO).  */
#define __F_SETOWN	6	/* Set owner (process receiving SIGIO).  */

#ifndef __USE_FILE_OFFSET64
# define F_GETLK	7	/* Get record locking info.  */
# define F_SETLK	8	/* Set record locking info (non-blocking).  */
# define F_SETLKW	9	/* Set record locking info (blocking).  */
#endif

#if __WORDSIZE == 64
# define F_GETLK64	7	/* Get record locking info.  */
# define F_SETLK64	8	/* Set record locking info (non-blocking).  */
# define F_SETLKW64	9	/* Set record locking info (blocking).  */
#endif

/* For posix fcntl() and `l_type' field of a `struct flock' for lockf().  */
#define F_RDLCK		1	/* Read lock.  */
#define F_WRLCK		2	/* Write lock.  */
#define F_UNLCK		3	/* Remove lock.  */

struct flock
  {
    short int l_type;	/* Type of lock: F_RDLCK, F_WRLCK, or F_UNLCK.  */
    short int l_whence;	/* Where `l_start' is relative to (like `lseek').  */
#ifndef __USE_FILE_OFFSET64
    __off_t l_start;	/* Offset where the lock begins.  */
    __off_t l_len;	/* Size of the locked area; zero means until EOF.  */
#else
    __off64_t l_start;	/* Offset where the lock begins.  */
    __off64_t l_len;	/* Size of the locked area; zero means until EOF.  */
#endif
    __pid_t l_pid;	/* Process holding the lock.  */
    short int __glibc_reserved;
  };

#ifdef __USE_LARGEFILE64
struct flock64
  {
    short int l_type;	/* Type of lock: F_RDLCK, F_WRLCK, or F_UNLCK.  */
    short int l_whence;	/* Where `l_start' is relative to (like `lseek').  */
    __off64_t l_start;	/* Offset where the lock begins.  */
    __off64_t l_len;	/* Size of the locked area; zero means until EOF.  */
    __pid_t l_pid;	/* Process holding the lock.  */
    short int __glibc_reserved;
  };
#endif

/* Include generic Linux declarations.  */
#include <bits/fcntl-linux.h>