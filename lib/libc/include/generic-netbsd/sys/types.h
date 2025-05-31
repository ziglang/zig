/*	$NetBSD: types.h,v 1.105.20.1 2023/05/15 10:34:58 martin Exp $	*/

/*-
 * Copyright (c) 1982, 1986, 1991, 1993, 1994
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
 *	@(#)types.h	8.4 (Berkeley) 1/21/94
 */

#ifndef _SYS_TYPES_H_
#define	_SYS_TYPES_H_

#include <sys/featuretest.h>

/* Machine type dependent parameters. */
#include <machine/types.h>

#include <machine/ansi.h>
#include <machine/int_types.h>


#include <sys/ansi.h>

#ifndef	_BSD_INT8_T_
typedef	__int8_t	int8_t;
#define	_BSD_INT8_T_
#endif

#ifndef	_BSD_UINT8_T_
typedef	__uint8_t	uint8_t;
#define	_BSD_UINT8_T_
#endif

#ifndef	_BSD_INT16_T_
typedef	__int16_t	int16_t;
#define	_BSD_INT16_T_
#endif

#ifndef	_BSD_UINT16_T_
typedef	__uint16_t	uint16_t;
#define	_BSD_UINT16_T_
#endif

#ifndef	_BSD_INT32_T_
typedef	__int32_t	int32_t;
#define	_BSD_INT32_T_
#endif

#ifndef	_BSD_UINT32_T_
typedef	__uint32_t	uint32_t;
#define	_BSD_UINT32_T_
#endif

#ifndef	_BSD_INT64_T_
typedef	__int64_t	int64_t;
#define	_BSD_INT64_T_
#endif

#ifndef	_BSD_UINT64_T_
typedef	__uint64_t	uint64_t;
#define	_BSD_UINT64_T_
#endif

typedef	uint8_t		u_int8_t;
typedef	uint16_t	u_int16_t;
typedef	uint32_t	u_int32_t;
typedef	uint64_t	u_int64_t;

#include <machine/endian.h>

#if defined(_NETBSD_SOURCE)
typedef	unsigned char	u_char;
typedef	unsigned short	u_short;
typedef	unsigned int	u_int;
typedef	unsigned long	u_long;

typedef unsigned char	unchar;		/* Sys V compatibility */
typedef	unsigned short	ushort;		/* Sys V compatibility */
typedef	unsigned int	uint;		/* Sys V compatibility */
typedef unsigned long	ulong;		/* Sys V compatibility */
#endif

typedef	uint64_t	u_quad_t;	/* quads */
typedef	int64_t		quad_t;
typedef	quad_t *	qaddr_t;

/*
 * The types longlong_t and u_longlong_t exist for use with the
 * Sun-derived XDR routines involving these types, and their usage
 * in other contexts is discouraged.  Further note that these types
 * may not be equivalent to "long long" and "unsigned long long",
 * they are only guaranteed to be signed and unsigned 64-bit types
 * respectively.  Portable programs that need 64-bit types should use
 * the C99 types int64_t and uint64_t instead.
 */

typedef	int64_t		longlong_t;	/* for XDR */
typedef	uint64_t	u_longlong_t;	/* for XDR */

typedef	int64_t		blkcnt_t;	/* fs block count */
typedef	int32_t		blksize_t;	/* fs optimal block size */

#ifndef	fsblkcnt_t
typedef	__fsblkcnt_t	fsblkcnt_t;	/* fs block count (statvfs) */
#define fsblkcnt_t	__fsblkcnt_t
#endif

#ifndef	fsfilcnt_t
typedef	__fsfilcnt_t	fsfilcnt_t;	/* fs file count */
#define fsfilcnt_t	__fsfilcnt_t
#endif

#if !defined(_KERNEL) && !defined(_STANDALONE)
/* We don't and shouldn't use caddr_t in the kernel anymore */
#ifndef	caddr_t
typedef	__caddr_t	caddr_t;	/* core address */
#define	caddr_t		__caddr_t
#endif
#endif

#ifdef __daddr_t
typedef	__daddr_t	daddr_t;	/* disk address */
#undef __daddr_t
#else
typedef	int64_t		daddr_t;	/* disk address */
#endif

typedef	uint64_t	dev_t;		/* device number */
typedef	uint32_t	fixpt_t;	/* fixed point number */

#ifndef	gid_t
typedef	__gid_t		gid_t;		/* group id */
#define	gid_t		__gid_t
#endif

typedef	uint32_t	id_t;		/* group id, process id or user id */
#ifdef __ino_t
/*
 * Some first stage bootloaders may want to avoid 64bit math, especially
 * when the firmware can only access small disks/partitions anyway.
 * Example: hppa/stand/xxboot
 */
typedef	__ino_t		ino_t;
#undef __ino_t
#else
typedef	uint64_t	ino_t;		/* inode number */
#endif
typedef	long		key_t;		/* IPC key (for Sys V IPC) */

#ifndef	mode_t
typedef	__mode_t	mode_t;		/* permissions */
#define	mode_t		__mode_t
#endif

#ifndef	accmode_t
typedef	__accmode_t	accmode_t;	/* access permissions */
#define	accmode_t	__accmode_t
#endif

typedef	uint32_t	nlink_t;	/* link count */

#ifndef	off_t
typedef	__off_t		off_t;		/* file offset */
#define	off_t		__off_t
#endif

#ifndef	pid_t
typedef	__pid_t		pid_t;		/* process id */
#define	pid_t		__pid_t
#endif
typedef int32_t		lwpid_t;	/* LWP id */
typedef uint64_t	rlim_t;		/* resource limit */
typedef	int32_t		segsz_t;	/* segment size */
typedef	int32_t		swblk_t;	/* swap offset */

#ifndef	uid_t
typedef	__uid_t		uid_t;		/* user id */
#define	uid_t		__uid_t
#endif

typedef int		mqd_t;

typedef	unsigned long	cpuid_t;

typedef	int		psetid_t;

typedef volatile __cpu_simple_lock_nv_t __cpu_simple_lock_t;

#if defined(_KERNEL) || defined(_STANDALONE)

#include <sys/stdbool.h>

/*
 * Deprecated Mach-style boolean_t type.  Should not be used by new code.
 */
typedef int	boolean_t;
#ifndef TRUE
#define	TRUE	1
#endif
#ifndef FALSE
#define	FALSE	0
#endif

#endif /* _KERNEL || _STANDALONE */

#if defined(_KERNEL) || defined(_LIBC) || defined(_KMEMUSER)
/*
 * semctl(2)'s argument structure.  This is here for the benefit of
 * <sys/syscallargs.h>.  It is not in the user's namespace in SUSv2.
 * The SUSv2 semctl(2) takes variable arguments.
 */
union __semun {
	int		val;		/* value for SETVAL */
	struct semid_ds	*buf;		/* buffer for IPC_STAT & IPC_SET */
	unsigned short	*array;		/* array for GETALL & SETALL */
};
#include <sys/stdint.h>
#endif /* _KERNEL || _LIBC || _KMEMUSER */

/*
 * These belong in unistd.h, but are placed here too to ensure that
 * long arguments will be promoted to off_t if the program fails to
 * include that header or explicitly cast them to off_t.
 */
#if defined(_NETBSD_SOURCE)
#ifndef __OFF_T_SYSCALLS_DECLARED
#define __OFF_T_SYSCALLS_DECLARED
#ifndef _KERNEL
#include <sys/cdefs.h>
__BEGIN_DECLS
off_t	 lseek(int, off_t, int);
int	 ftruncate(int, off_t);
int	 truncate(const char *, off_t);
__END_DECLS
#endif /* !_KERNEL */
#endif /* __OFF_T_SYSCALLS_DECLARED */
#endif /* defined(_NETBSD_SOURCE) */

#if defined(_NETBSD_SOURCE)
/* Major, minor numbers, dev_t's. */
typedef int32_t __devmajor_t, __devminor_t;
#define devmajor_t __devmajor_t
#define devminor_t __devminor_t
#define NODEVMAJOR (-1)
#define	major(x)	((devmajor_t)(((uint32_t)(x) & 0x000fff00) >>  8))
#define	minor(x)	((devminor_t)((((uint32_t)(x) & 0xfff00000) >> 12) | \
				   (((uint32_t)(x) & 0x000000ff) >>  0)))
#define	makedev(x,y)	((dev_t)((((dev_t)(x) <<  8) & 0x000fff00U) | \
				 (((dev_t)(y) << 12) & 0xfff00000U) | \
				 (((dev_t)(y) <<  0) & 0x000000ffU)))
#endif

#ifdef	_BSD_CLOCK_T_
typedef	_BSD_CLOCK_T_		clock_t;
#undef	_BSD_CLOCK_T_
#endif

#ifdef	_BSD_PTRDIFF_T_
typedef	_BSD_PTRDIFF_T_		ptrdiff_t;
#undef	_BSD_PTRDIFF_T_
#endif

#ifdef	_BSD_SIZE_T_
typedef	_BSD_SIZE_T_		size_t;
#define _SIZE_T
#undef	_BSD_SIZE_T_
#endif

#ifdef	_BSD_SSIZE_T_
typedef	_BSD_SSIZE_T_		ssize_t;
#undef	_BSD_SSIZE_T_
#endif

#ifdef	_BSD_TIME_T_
typedef	_BSD_TIME_T_		time_t;
#undef	_BSD_TIME_T_
#endif

#ifdef	_BSD_CLOCKID_T_
typedef	_BSD_CLOCKID_T_		clockid_t;
#undef	_BSD_CLOCKID_T_
#endif

#ifdef	_BSD_TIMER_T_
typedef	_BSD_TIMER_T_		timer_t;
#undef	_BSD_TIMER_T_
#endif

#ifdef	_BSD_SUSECONDS_T_
typedef	_BSD_SUSECONDS_T_	suseconds_t;
#undef	_BSD_SUSECONDS_T_
#endif

#ifdef	_BSD_USECONDS_T_
typedef	_BSD_USECONDS_T_	useconds_t;
#undef	_BSD_USECONDS_T_
#endif

#ifdef _NETBSD_SOURCE
#include <sys/fd_set.h>

#define	NBBY			8

typedef struct kauth_cred *kauth_cred_t;

typedef int pri_t;

#endif

#if defined(__STDC__) && (defined(_KERNEL) || defined(_KMEMUSER))
/*
 * Forward structure declarations for function prototypes.  We include the
 * common structures that cross subsystem boundaries here; others are mostly
 * used in the same place that the structure is defined.
 */
struct	lwp;
typedef struct lwp lwp_t;
struct	__ucontext;
struct	proc;
typedef struct proc proc_t;
struct	pgrp;
struct	rusage;
struct	file;
typedef struct file file_t;
struct	buf;
typedef struct buf buf_t;
struct	tty;
struct	uio;
#endif

#if defined(_KERNEL) || defined(_STANDALONE)
#define SET(t, f)	((t) |= (f))
#define	ISSET(t, f)	((t) & (f))
#define	CLR(t, f)	((t) &= ~(f))
#endif

#if !defined(_KERNEL) && !defined(_STANDALONE)
#if (_POSIX_C_SOURCE - 0L) >= 199506L || (_XOPEN_SOURCE - 0) >= 500 || \
    defined(_NETBSD_SOURCE)
#include <pthread_types.h>
#endif
#endif

#endif /* !_SYS_TYPES_H_ */