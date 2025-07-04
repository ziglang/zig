/*	$NetBSD: fcntl.h,v 1.54 2020/03/30 20:17:42 kamil Exp $	*/

/*-
 * Copyright (c) 1983, 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)fcntl.h	8.3 (Berkeley) 1/21/94
 */

#ifndef _SYS_FCNTL_H_
#define	_SYS_FCNTL_H_

/*
 * This file includes the definitions for open and fcntl
 * described by POSIX for <fcntl.h>; it also includes
 * related kernel definitions.
 */

#ifndef _KERNEL
#include <sys/featuretest.h>
#include <sys/types.h>
#if defined(_XOPEN_SOURCE)
#include <sys/stat.h>
#endif /* _XOPEN_SOURCE */
#endif /* !_KERNEL */

/*
 * File status flags: these are used by open(2), fcntl(2).
 * They are also used (indirectly) in the kernel file structure f_flags,
 * which is a superset of the open/fcntl flags.  Open flags and f_flags
 * are inter-convertible using OFLAGS(fflags) and FFLAGS(oflags).
 * Open/fcntl flags begin with O_; kernel-internal flags begin with F.
 */
/* open-only flags */
#define	O_RDONLY	0x00000000	/* open for reading only */
#define	O_WRONLY	0x00000001	/* open for writing only */
#define	O_RDWR		0x00000002	/* open for reading and writing */
#define	O_ACCMODE	0x00000003	/* mask for above modes */

/*
 * Kernel encoding of open mode; separate read and write bits that are
 * independently testable: 1 greater than the above.
 *
 * XXX
 * FREAD and FWRITE are excluded from the #ifdef _KERNEL so that TIOCFLUSH,
 * which was documented to use FREAD/FWRITE, continues to work.
 */
#if defined(_NETBSD_SOURCE)
#define	FREAD		0x00000001
#define	FWRITE		0x00000002
#endif
#define	O_NONBLOCK	0x00000004	/* no delay */
#define	O_APPEND	0x00000008	/* set append mode */
#if defined(_NETBSD_SOURCE)
#define	O_SHLOCK	0x00000010	/* open with shared file lock */
#define	O_EXLOCK	0x00000020	/* open with exclusive file lock */
#define	O_ASYNC		0x00000040	/* signal pgrp when data ready */
#endif
#if (_POSIX_C_SOURCE - 0) >= 199309L || \
    (defined(_XOPEN_SOURCE) && defined(_XOPEN_SOURCE_EXTENDED)) || \
    (_XOPEN_SOURCE - 0) >= 500 || defined(_NETBSD_SOURCE)
#define	O_SYNC		0x00000080	/* synchronous writes */
#endif
#if (_POSIX_C_SOURCE - 0) >= 200809L || defined(_NETBSD_SOURCE)
#define	O_NOFOLLOW	0x00000100	/* don't follow symlinks on the last */
					/* path component */
#endif
#define	O_CREAT		0x00000200	/* create if nonexistent */
#define	O_TRUNC		0x00000400	/* truncate to zero length */
#define	O_EXCL		0x00000800	/* error if already exists */

/* defined by POSIX 1003.1; BSD default, but required to be bitwise distinct */
#define	O_NOCTTY	0x00008000	/* don't assign controlling terminal */

#if (_POSIX_C_SOURCE - 0) >= 199309L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
#define	O_DSYNC		0x00010000	/* write: I/O data completion */
#define	O_RSYNC		0x00020000	/* read: I/O completion as for write */
#endif

#if defined(_NETBSD_SOURCE)
#define	O_ALT_IO	0x00040000	/* use alternate i/o semantics */
#define	O_DIRECT	0x00080000	/* direct I/O hint */
#endif

#define	O_DIRECTORY	0x00200000	/* fail if not a directory */
#define	O_CLOEXEC	0x00400000	/* set close on exec */
#if (_POSIX_C_SOURCE - 0) >= 200809L || (_XOPEN_SOURCE - 0 >= 700) || \
    defined(_NETBSD_SOURCE)
#define	O_SEARCH	0x00800000	/* skip search permission checks */
#endif
#if defined(_NETBSD_SOURCE)
#define	O_NOSIGPIPE	0x01000000	/* don't deliver sigpipe */
#define	O_REGULAR	0x02000000	/* fail if not a regular file */
#define	O_EXEC		0x04000000	/* open for executing only */
#endif

#ifdef _KERNEL
/* convert from open() flags to/from fflags; convert O_RD/WR to FREAD/FWRITE */
#define	FFLAGS(oflags)	((oflags) + 1)
#define	OFLAGS(fflags)	((fflags) - 1)

/* all bits settable during open(2) */
#define	O_MASK		(O_ACCMODE|O_NONBLOCK|O_APPEND|O_SHLOCK|O_EXLOCK|\
			 O_ASYNC|O_SYNC|O_CREAT|O_TRUNC|O_EXCL|O_DSYNC|\
			 O_RSYNC|O_NOCTTY|O_ALT_IO|O_NOFOLLOW|O_DIRECT|\
			 O_DIRECTORY|O_CLOEXEC|O_NOSIGPIPE|O_REGULAR|O_EXEC)

#define	FEXEC		O_EXEC
#define	FMARK		0x00001000	/* mark during gc() */
#define	FDEFER		0x00002000	/* defer for next gc pass */
#define	FHASLOCK	0x00004000	/* descriptor holds advisory lock */
#define	FSCAN		0x00100000	/* scan during gc passes */
#define	FSILENT		0x40000000	/* suppress kernel error messages */
#define	FKIOCTL		0x80000000	/* kernel originated ioctl */
/* bits settable by fcntl(F_SETFL, ...) */
#define	FCNTLFLAGS	(FAPPEND|FASYNC|FFSYNC|FNONBLOCK|FDSYNC|FRSYNC|FALTIO|\
			 FDIRECT|FNOSIGPIPE)
/* bits to save after open(2) */
#define	FMASK		(FREAD|FWRITE|FCNTLFLAGS|FEXEC)
#endif /* _KERNEL */

/*
 * The O_* flags used to have only F* names, which were used in the kernel
 * and by fcntl.  We retain the F* names for the kernel f_flags field
 * and for backward compatibility for fcntl.
 */
#if defined(_NETBSD_SOURCE)
#define	FAPPEND		O_APPEND	/* kernel/compat */
#define	FASYNC		O_ASYNC		/* kernel/compat */
#define	O_FSYNC		O_SYNC		/* compat */
#define	FNDELAY		O_NONBLOCK	/* compat */
#define	O_NDELAY	O_NONBLOCK	/* compat */
#endif
#if defined(_KERNEL)
#define	FNOSIGPIPE	O_NOSIGPIPE	/* kernel */
#define	FNONBLOCK	O_NONBLOCK	/* kernel */
#define	FFSYNC		O_SYNC		/* kernel */
#define	FDSYNC		O_DSYNC		/* kernel */
#define	FRSYNC		O_RSYNC		/* kernel */
#define	FALTIO		O_ALT_IO	/* kernel */
#define	FDIRECT		O_DIRECT	/* kernel */
#endif

/*
 * Constants used for fcntl(2)
 */

/* command values */
#define	F_DUPFD		0		/* duplicate file descriptor */
#define	F_GETFD		1		/* get file descriptor flags */
#define	F_SETFD		2		/* set file descriptor flags */
#define	F_GETFL		3		/* get file status flags */
#define	F_SETFL		4		/* set file status flags */
#if (_POSIX_C_SOURCE - 0) >= 200112L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
#define	F_GETOWN	5		/* get SIGIO/SIGURG proc/pgrp */
#define	F_SETOWN	6		/* set SIGIO/SIGURG proc/pgrp */
#endif
#define	F_GETLK		7		/* get record locking information */
#define	F_SETLK		8		/* set record locking information */
#define	F_SETLKW	9		/* F_SETLK; wait if blocked */
#if defined(_NETBSD_SOURCE)
#define	F_CLOSEM	10		/* close all fds >= to the one given */
#define	F_MAXFD		11		/* return the max open fd */
#endif
#if (_POSIX_C_SOURCE - 0) >= 200809L || defined(_NETBSD_SOURCE)
#define	F_DUPFD_CLOEXEC	12		/* close on exec duplicated fd */
#endif
#if defined(_NETBSD_SOURCE)
#define	F_GETNOSIGPIPE	13		/* get SIGPIPE disposition */
#define	F_SETNOSIGPIPE	14		/* set SIGPIPE disposition */
#define	F_GETPATH	15		/* get pathname associated with fd */
#endif

/* file descriptor flags (F_GETFD, F_SETFD) */
#define	FD_CLOEXEC	1		/* close-on-exec flag */

/* record locking flags (F_GETLK, F_SETLK, F_SETLKW) */
#define	F_RDLCK		1		/* shared or read lock */
#define	F_UNLCK		2		/* unlock */
#define	F_WRLCK		3		/* exclusive or write lock */
#ifdef _KERNEL
#define	F_WAIT		0x010		/* Wait until lock is granted */
#define	F_FLOCK		0x020	 	/* Use flock(2) semantics for lock */
#define	F_POSIX		0x040	 	/* Use POSIX semantics for lock */
#endif

/* Constants for fcntl's passed to the underlying fs - like ioctl's. */
#if defined(_NETBSD_SOURCE)
#define	F_PARAM_MASK	0xfff
#define	F_PARAM_LEN(x)	(((x) >> 16) & F_PARAM_MASK)
#define	F_PARAM_MAX	4095
#define	F_FSCTL		(int)0x80000000	/* This fcntl goes to the fs */
#define	F_FSVOID	(int)0x40000000	/* no parameters */
#define	F_FSOUT		(int)0x20000000	/* copy out parameter */
#define	F_FSIN		(int)0x10000000	/* copy in parameter */
#define	F_FSINOUT	(F_FSIN | F_FSOUT)
#define	F_FSDIRMASK	(int)0x70000000	/* mask for IN/OUT/VOID */
#define	F_FSPRIV	(int)0x00008000	/* command is fs-specific */

/*
 * Define command macros for operations which, if implemented, must be
 * the same for all fs's.
 */
#define	_FCN(inout, num, len) \
		(F_FSCTL | inout | ((len & F_PARAM_MASK) << 16) | (num))
#define	_FCNO(c)	_FCN(F_FSVOID,	(c), 0)
#define	_FCNR(c, t)	_FCN(F_FSIN,	(c), (int)sizeof(t))
#define	_FCNW(c, t)	_FCN(F_FSOUT,	(c), (int)sizeof(t))
#define	_FCNRW(c, t)	_FCN(F_FSINOUT,	(c), (int)sizeof(t))

/*
 * Define command macros for fs-specific commands.
 */
#define	_FCN_FSPRIV(inout, fs, num, len) \
	(F_FSCTL | F_FSPRIV | inout | ((len & F_PARAM_MASK) << 16) |	\
	 (fs) << 8 | (num))
#define	_FCNO_FSPRIV(f, c)	_FCN_FSPRIV(F_FSVOID,  (f), (c), 0)
#define	_FCNR_FSPRIV(f, c, t)	_FCN_FSPRIV(F_FSIN,    (f), (c), (int)sizeof(t))
#define	_FCNW_FSPRIV(f, c, t)	_FCN_FSPRIV(F_FSOUT,   (f), (c), (int)sizeof(t))
#define	_FCNRW_FSPRIV(f, c, t)	_FCN_FSPRIV(F_FSINOUT, (f), (c), (int)sizeof(t))

#endif /* _NETBSD_SOURCE */

/*
 * Advisory file segment locking data type -
 * information passed to system by user
 */
struct flock {
	off_t	l_start;	/* starting offset */
	off_t	l_len;		/* len = 0 means until end of file */
	pid_t	l_pid;		/* lock owner */
	short	l_type;		/* lock type: read/write, etc. */
	short	l_whence;	/* type of l_start */
};


#if defined(_NETBSD_SOURCE)
/* lock operations for flock(2) */
#define	LOCK_SH		0x01		/* shared file lock */
#define	LOCK_EX		0x02		/* exclusive file lock */
#define	LOCK_NB		0x04		/* don't block when locking */
#define	LOCK_UN		0x08		/* unlock file */
#endif

/* Always ensure that these are consistent with <stdio.h> and <unistd.h>! */
#ifndef	SEEK_SET
#define	SEEK_SET	0	/* set file offset to offset */
#endif
#ifndef	SEEK_CUR
#define	SEEK_CUR	1	/* set file offset to current plus offset */
#endif
#ifndef	SEEK_END
#define	SEEK_END	2	/* set file offset to EOF plus offset */
#endif

/*
 * posix_advise advisories.
 */

#define	POSIX_FADV_NORMAL	0	/* default advice / no advice */
#define	POSIX_FADV_RANDOM	1	/* random access */
#define	POSIX_FADV_SEQUENTIAL	2	/* sequential access(lower to higher) */
#define	POSIX_FADV_WILLNEED	3	/* be needed in near future */
#define	POSIX_FADV_DONTNEED	4	/* not be needed in near future */
#define	POSIX_FADV_NOREUSE	5	/* be accessed once */

/*
 * Constants for X/Open Extended API set 2 (a.k.a. C063)
 */
#if (_POSIX_C_SOURCE - 0) >= 200809L || (_XOPEN_SOURCE - 0 >= 700) || \
    defined(_NETBSD_SOURCE)
#define	AT_FDCWD		-100	/* Use cwd for relative link target */
#define	AT_EACCESS		0x100	/* Use euig/egid for access checks */
#define	AT_SYMLINK_NOFOLLOW	0x200	/* Do not follow symlinks */
#define	AT_SYMLINK_FOLLOW	0x400	/* Follow symlinks */
#define	AT_REMOVEDIR		0x800	/* Remove directory only */
#endif


#ifndef _KERNEL
#include <sys/cdefs.h>

__BEGIN_DECLS
int	open(const char *, int, ...);
int	creat(const char *, mode_t);
int	fcntl(int, int, ...);
#if defined(_NETBSD_SOURCE)
int	flock(int, int);
#endif /* _NETBSD_SOURCE */
int	posix_fadvise(int, off_t, off_t, int);

/*
 * The Open Group Base Specifications, Issue 6; IEEE Std 1003.1-2001 (POSIX)
 */
#if (_POSIX_C_SOURCE - 0) >= 200112L || (_XOPEN_SOURCE - 0) >= 600 || \
    defined(_NETBSD_SOURCE)
int	 posix_fallocate(int, off_t, off_t);
#endif

/*
 * X/Open Extended API set 2 (a.k.a. C063)
 */
#if (_POSIX_C_SOURCE - 0) >= 200809L || (_XOPEN_SOURCE - 0 >= 700) || \
    defined(_NETBSD_SOURCE)
int	openat(int, const char *, int, ...);
#endif

__END_DECLS
#endif /* !_KERNEL */

#endif /* !_SYS_FCNTL_H_ */