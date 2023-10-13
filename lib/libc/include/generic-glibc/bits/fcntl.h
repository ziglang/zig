/* O_*, F_*, FD_* bit values for Linux.
   Copyright (C) 1995-2023 Free Software Foundation, Inc.
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

#ifndef	_FCNTL_H
# error "Never use <bits/fcntl.h> directly; include <fcntl.h> instead."
#endif

#include <sgidefs.h>

#define O_APPEND	 0x0008
#define O_SYNC		 0x4010
#define O_NONBLOCK	 0x0080
#define O_CREAT		 0x0100	/* not fcntl */
#define O_TRUNC		 0x0200	/* not fcntl */
#define O_EXCL		 0x0400	/* not fcntl */
#define O_NOCTTY	 0x0800	/* not fcntl */
#define O_ASYNC		 0x1000

#define __O_DIRECT	 0x8000	/* Direct disk access hint.  */
#define __O_DSYNC	 0x0010	/* Synchronize data.  */

#if _MIPS_SIM == _ABI64
/* Not necessary, files are always with 64bit off_t.  */
# define __O_LARGEFILE  0
#else
# define __O_LARGEFILE	0x2000	/* Allow large file opens.  */
#endif

#ifndef __USE_FILE_OFFSET64
# define F_GETLK	14	/* Get record locking info.  */
# define F_SETLK	6	/* Set record locking info (non-blocking).  */
# define F_SETLKW	7	/* Set record locking info (blocking).	*/
#else
# define F_GETLK	F_GETLK64  /* Get record locking info.	*/
# define F_SETLK	F_SETLK64  /* Set record locking info (non-blocking).*/
# define F_SETLKW	F_SETLKW64 /* Set record locking info (blocking).  */
#endif

#if _MIPS_SIM != _ABI64
# define F_GETLK64	33	/* Get record locking info.  */
# define F_SETLK64	34	/* Set record locking info (non-blocking).  */
# define F_SETLKW64	35	/* Set record locking info (blocking).	*/
#else
# define F_GETLK64	14	/* Get record locking info.	*/
# define F_SETLK64	6	/* Set record locking info (non-blocking).*/
# define F_SETLKW64	7	/* Set record locking info (blocking).  */
#endif

#define __F_SETOWN	24	/* Get owner (process receiving SIGIO).  */
#define __F_GETOWN	23	/* Set owner (process receiving SIGIO).  */

struct flock
  {
    short int l_type;	/* Type of lock: F_RDLCK, F_WRLCK, or F_UNLCK.	*/
    short int l_whence;	/* Where `l_start' is relative to (like `lseek').  */
#ifndef __USE_FILE_OFFSET64
    __off_t l_start;	/* Offset where the lock begins.  */
    __off_t l_len;	/* Size of the locked area; zero means until EOF.  */
#if _MIPS_SIM != _ABI64
    /* The 64-bit flock structure, used by the n64 ABI, and for 64-bit
       fcntls in o32 and n32, never has this field.  */
    long int l_sysid;
#endif
#else
    __off64_t l_start;	/* Offset where the lock begins.  */
    __off64_t l_len;	/* Size of the locked area; zero means until EOF.  */
#endif
    __pid_t l_pid;	/* Process holding the lock.  */
#if ! defined __USE_FILE_OFFSET64 && _MIPS_SIM != _ABI64
    /* The 64-bit flock structure, used by the n64 ABI, and for 64-bit
       flock in o32 and n32, never has this field.  */
    long int __glibc_reserved0[4];
#endif
  };
typedef struct flock flock_t;

#ifdef __USE_LARGEFILE64
struct flock64
  {
    short int l_type;	/* Type of lock: F_RDLCK, F_WRLCK, or F_UNLCK.	*/
    short int l_whence;	/* Where `l_start' is relative to (like `lseek').  */
    __off64_t l_start;	/* Offset where the lock begins.  */
    __off64_t l_len;	/* Size of the locked area; zero means until EOF.  */
    __pid_t l_pid;	/* Process holding the lock.  */
  };
#endif

/* Include generic Linux declarations.  */
#include <bits/fcntl-linux.h>