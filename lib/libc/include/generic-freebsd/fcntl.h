/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
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

#include <sys/cdefs.h>
#include <sys/_types.h>

#ifndef _MODE_T_DECLARED
typedef	__mode_t	mode_t;
#define	_MODE_T_DECLARED
#endif

#ifndef _OFF_T_DECLARED
typedef	__off_t		off_t;
#define	_OFF_T_DECLARED
#endif

#ifndef _PID_T_DECLARED
typedef	__pid_t		pid_t;
#define	_PID_T_DECLARED
#endif

/*
 * File status flags: these are used by open(2), fcntl(2).
 * They are also used (indirectly) in the kernel file structure f_flags,
 * which is a superset of the open/fcntl flags.  Open flags and f_flags
 * are inter-convertible using OFLAGS(fflags) and FFLAGS(oflags).
 * Open/fcntl flags begin with O_; kernel-internal flags begin with F.
 */
/* open-only flags */
#define	O_RDONLY	0x0000		/* open for reading only */
#define	O_WRONLY	0x0001		/* open for writing only */
#define	O_RDWR		0x0002		/* open for reading and writing */
#define	O_ACCMODE	0x0003		/* mask for above modes */

/*
 * Kernel encoding of open mode; separate read and write bits that are
 * independently testable: 1 greater than the above.
 *
 * XXX
 * FREAD and FWRITE are excluded from the #ifdef _KERNEL so that TIOCFLUSH,
 * which was documented to use FREAD/FWRITE, continues to work.
 */
#if __BSD_VISIBLE
#define	FREAD		0x0001
#define	FWRITE		0x0002
#endif
#define	O_NONBLOCK	0x0004		/* no delay */
#define	O_APPEND	0x0008		/* set append mode */
#if __BSD_VISIBLE
#define	O_SHLOCK	0x0010		/* open with shared file lock */
#define	O_EXLOCK	0x0020		/* open with exclusive file lock */
#define	O_ASYNC		0x0040		/* signal pgrp when data ready */
#define	O_FSYNC		0x0080		/* synchronous writes */
#endif
#define	O_SYNC		0x0080		/* POSIX synonym for O_FSYNC */
#if __POSIX_VISIBLE >= 200809
#define	O_NOFOLLOW	0x0100		/* don't follow symlinks */
#endif
#define	O_CREAT		0x0200		/* create if nonexistent */
#define	O_TRUNC		0x0400		/* truncate to zero length */
#define	O_EXCL		0x0800		/* error if already exists */
#ifdef _KERNEL
#define	FHASLOCK	0x4000		/* descriptor holds advisory lock */
#endif

/* Defined by POSIX 1003.1; BSD default, but must be distinct from O_RDONLY. */
#define	O_NOCTTY	0x8000		/* don't assign controlling terminal */

#if __BSD_VISIBLE
/* Attempt to bypass buffer cache */
#define	O_DIRECT	0x00010000
#endif

#if __POSIX_VISIBLE >= 200809
#define	O_DIRECTORY	0x00020000	/* Fail if not directory */
#define	O_EXEC		0x00040000	/* Open for execute only */
#define	O_SEARCH	O_EXEC
#endif
#ifdef	_KERNEL
#define	FEXEC		O_EXEC
#define	FSEARCH		O_SEARCH
#endif

#if __POSIX_VISIBLE >= 200809
/* Defined by POSIX 1003.1-2008; BSD default, but reserve for future use. */
#define	O_TTY_INIT	0x00080000	/* Restore default termios attributes */

#define	O_CLOEXEC	0x00100000
#endif

#if __BSD_VISIBLE
#define	O_VERIFY	0x00200000	/* open only after verification */
#define O_PATH		0x00400000	/* fd is only a path */
#define	O_RESOLVE_BENEATH 0x00800000	/* Do not allow name resolution to walk
					   out of cwd */
#endif

#define	O_DSYNC		0x01000000	/* POSIX data sync */
#if __BSD_VISIBLE
#define	O_EMPTY_PATH	0x02000000
#endif

/*
 * XXX missing O_RSYNC.
 */

#ifdef _KERNEL

/* Only for devfs d_close() flags. */
#define	FLASTCLOSE	O_DIRECTORY
#define	FREVOKE		O_VERIFY
/* Only for fo_close() from half-succeeded open */
#define	FOPENFAILED	O_TTY_INIT
/* Only for O_PATH files which passed ACCESS FREAD check on open */
#define	FKQALLOWED	O_RESOLVE_BENEATH

/* convert from open() flags to/from fflags; convert O_RD/WR to FREAD/FWRITE */
#define	FFLAGS(oflags)	((oflags) & O_EXEC ? (oflags) : (oflags) + 1)
#define	OFLAGS(fflags)	\
    (((fflags) & (O_EXEC | O_PATH)) != 0 ? (fflags) : (fflags) - 1)

/* bits to save after open */
#define	FMASK	(FREAD|FWRITE|FAPPEND|FASYNC|FFSYNC|FDSYNC|FNONBLOCK| \
		 O_DIRECT|FEXEC|O_PATH)
/* bits settable by fcntl(F_SETFL, ...) */
#define	FCNTLFLAGS	(FAPPEND|FASYNC|FFSYNC|FDSYNC|FNONBLOCK|FRDAHEAD|O_DIRECT)

#if defined(COMPAT_FREEBSD7) || defined(COMPAT_FREEBSD6) || \
    defined(COMPAT_FREEBSD5) || defined(COMPAT_FREEBSD4)
/*
 * Set by shm_open(3) in older libc's to get automatic MAP_ASYNC
 * behavior for POSIX shared memory objects (which are otherwise
 * implemented as plain files).
 */
#define	FPOSIXSHM	O_NOFOLLOW
#undef FCNTLFLAGS
#define	FCNTLFLAGS	(FAPPEND|FASYNC|FFSYNC|FNONBLOCK|FPOSIXSHM|FRDAHEAD| \
			 O_DIRECT)
#endif
#endif

/*
 * The O_* flags used to have only F* names, which were used in the kernel
 * and by fcntl.  We retain the F* names for the kernel f_flag field
 * and for backward compatibility for fcntl.  These flags are deprecated.
 */
#if __BSD_VISIBLE
#define	FAPPEND		O_APPEND	/* kernel/compat */
#define	FASYNC		O_ASYNC		/* kernel/compat */
#define	FFSYNC		O_FSYNC		/* kernel */
#define	FDSYNC		O_DSYNC		/* kernel */
#define	FNONBLOCK	O_NONBLOCK	/* kernel */
#define	FNDELAY		O_NONBLOCK	/* compat */
#define	O_NDELAY	O_NONBLOCK	/* compat */
#endif

/*
 * Historically, we ran out of bits in f_flag (which was once a short).
 * However, the flag bits not set in FMASK are only meaningful in the
 * initial open syscall.  Those bits were thus given a
 * different meaning for fcntl(2).
 */
#if __BSD_VISIBLE
/* Read ahead */
#define	FRDAHEAD	O_CREAT
#endif

#if __POSIX_VISIBLE >= 200809
/*
 * Magic value that specify the use of the current working directory
 * to determine the target of relative file paths in the openat() and
 * similar syscalls.
 */
#define	AT_FDCWD		-100

/*
 * Miscellaneous flags for the *at() syscalls.
 */
#define	AT_EACCESS		0x0100	/* Check access using effective user
					   and group ID */
#define	AT_SYMLINK_NOFOLLOW	0x0200	/* Do not follow symbolic links */
#define	AT_SYMLINK_FOLLOW	0x0400	/* Follow symbolic link */
#define	AT_REMOVEDIR		0x0800	/* Remove directory instead of file */
#endif	/* __POSIX_VISIBLE >= 200809 */
#if __BSD_VISIBLE
/* #define AT_UNUSED1		0x1000 *//* Was AT_BENEATH */
#define	AT_RESOLVE_BENEATH	0x2000	/* Do not allow name resolution
					   to walk out of dirfd */
#define	AT_EMPTY_PATH		0x4000	/* Operate on dirfd if path is empty */
#endif	/* __BSD_VISIBLE */

/*
 * Constants used for fcntl(2)
 */

/* command values */
#define	F_DUPFD		0		/* duplicate file descriptor */
#define	F_GETFD		1		/* get file descriptor flags */
#define	F_SETFD		2		/* set file descriptor flags */
#define	F_GETFL		3		/* get file status flags */
#define	F_SETFL		4		/* set file status flags */
#if __XSI_VISIBLE || __POSIX_VISIBLE >= 200112
#define	F_GETOWN	5		/* get SIGIO/SIGURG proc/pgrp */
#define	F_SETOWN	6		/* set SIGIO/SIGURG proc/pgrp */
#endif
#if __BSD_VISIBLE
#define	F_OGETLK	7		/* get record locking information */
#define	F_OSETLK	8		/* set record locking information */
#define	F_OSETLKW	9		/* F_SETLK; wait if blocked */
#define	F_DUP2FD	10		/* duplicate file descriptor to arg */
#endif
#define	F_GETLK		11		/* get record locking information */
#define	F_SETLK		12		/* set record locking information */
#define	F_SETLKW	13		/* F_SETLK; wait if blocked */
#if __BSD_VISIBLE
#define	F_SETLK_REMOTE	14		/* debugging support for remote locks */
#define	F_READAHEAD	15		/* read ahead */
#define	F_RDAHEAD	16		/* Darwin compatible read ahead */
#endif
#if __POSIX_VISIBLE >= 200809
#define	F_DUPFD_CLOEXEC	17		/* Like F_DUPFD, but FD_CLOEXEC is set */
#endif
#if __BSD_VISIBLE
#define	F_DUP2FD_CLOEXEC 18		/* Like F_DUP2FD, but FD_CLOEXEC is set */
#define	F_ADD_SEALS	19
#define	F_GET_SEALS	20
#define	F_ISUNIONSTACK	21		/* Kludge for libc, don't use it. */
#define	F_KINFO		22		/* Return kinfo_file for this fd */

/* Seals (F_ADD_SEALS, F_GET_SEALS). */
#define	F_SEAL_SEAL	0x0001		/* Prevent adding sealings */
#define	F_SEAL_SHRINK	0x0002		/* May not shrink */
#define	F_SEAL_GROW	0x0004		/* May not grow */
#define	F_SEAL_WRITE	0x0008		/* May not write */
#endif	/* __BSD_VISIBLE */

/* file descriptor flags (F_GETFD, F_SETFD) */
#define	FD_CLOEXEC	1		/* close-on-exec flag */

/* record locking flags (F_GETLK, F_SETLK, F_SETLKW) */
#define	F_RDLCK		1		/* shared or read lock */
#define	F_UNLCK		2		/* unlock */
#define	F_WRLCK		3		/* exclusive or write lock */
#if __BSD_VISIBLE
#define	F_UNLCKSYS	4		/* purge locks for a given system ID */ 
#define	F_CANCEL	5		/* cancel an async lock request */
#endif
#ifdef _KERNEL
#define	F_WAIT		0x010		/* Wait until lock is granted */
#define	F_FLOCK		0x020	 	/* Use flock(2) semantics for lock */
#define	F_POSIX		0x040	 	/* Use POSIX semantics for lock */
#define	F_REMOTE	0x080		/* Lock owner is remote NFS client */
#define	F_NOINTR	0x100		/* Ignore signals when waiting */
#define	F_FIRSTOPEN	0x200		/* First right to advlock file */
#endif

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
	int	l_sysid;	/* remote system id or zero for local */
};

#if __BSD_VISIBLE
/*
 * Old advisory file segment locking data type,
 * before adding l_sysid.
 */
struct __oflock {
	off_t	l_start;	/* starting offset */
	off_t	l_len;		/* len = 0 means until end of file */
	pid_t	l_pid;		/* lock owner */
	short	l_type;		/* lock type: read/write, etc. */
	short	l_whence;	/* type of l_start */
};

/*
 * Space control offset/length description
 */
struct spacectl_range {
	off_t	r_offset;	/* starting offset */
	off_t	r_len;	/* length */
};
#endif

#if __BSD_VISIBLE
/* lock operations for flock(2) */
#define	LOCK_SH		0x01		/* shared file lock */
#define	LOCK_EX		0x02		/* exclusive file lock */
#define	LOCK_NB		0x04		/* don't block when locking */
#define	LOCK_UN		0x08		/* unlock file */
#endif

#if __POSIX_VISIBLE >= 200112
/*
 * Advice to posix_fadvise
 */
#define	POSIX_FADV_NORMAL	0	/* no special treatment */
#define	POSIX_FADV_RANDOM	1	/* expect random page references */
#define	POSIX_FADV_SEQUENTIAL	2	/* expect sequential page references */
#define	POSIX_FADV_WILLNEED	3	/* will need these pages */
#define	POSIX_FADV_DONTNEED	4	/* dont need these pages */
#define	POSIX_FADV_NOREUSE	5	/* access data only once */
#endif

#ifdef __BSD_VISIBLE
/*
 * Magic value that specify that corresponding file descriptor to filename
 * is unknown and sanitary check should be omitted in the funlinkat() and
 * similar syscalls.
 */
#define	FD_NONE			-200

/*
 * Commands for fspacectl(2)
 */
#define SPACECTL_DEALLOC	1	/* deallocate space */

/*
 * fspacectl(2) flags
 */
#define SPACECTL_F_SUPPORTED	0
#endif

#ifndef _KERNEL
__BEGIN_DECLS
int	open(const char *, int, ...);
int	creat(const char *, mode_t);
int	fcntl(int, int, ...);
#if __BSD_VISIBLE
int	flock(int, int);
int	fspacectl(int, int, const struct spacectl_range *, int,
	    struct spacectl_range *);
#endif
#if __POSIX_VISIBLE >= 200809
int	openat(int, const char *, int, ...);
#endif
#if __POSIX_VISIBLE >= 200112
int	posix_fadvise(int, off_t, off_t, int);
int	posix_fallocate(int, off_t, off_t);
#endif
__END_DECLS
#endif

#endif /* !_SYS_FCNTL_H_ */