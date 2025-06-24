/*	$NetBSD: unistd.h,v 1.63 2020/05/16 18:31:53 christos Exp $	*/

/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)unistd.h	8.2 (Berkeley) 1/7/94
 */

#ifndef _SYS_UNISTD_H_
#define	_SYS_UNISTD_H_

#include <sys/featuretest.h>

/* compile-time symbolic constants */
#define	_POSIX_JOB_CONTROL	1
				/* implementation supports job control */

/*
 * According to POSIX 1003.1:
 * "The saved set-user-ID capability allows a program to regain the
 * effective user ID established at the last exec call."
 * However, the setuid/setgid function as specified by POSIX 1003.1 does
 * not allow changing the effective ID from the super-user without also
 * changed the saved ID, so it is impossible to get super-user privileges
 * back later.  Instead we provide this feature independent of the current
 * effective ID through the seteuid/setegid function.  In addition, we do
 * not use the saved ID as specified by POSIX 1003.1 in setuid/setgid,
 * because this would make it impossible for a set-user-ID executable
 * owned by a user other than the super-user to permanently revoke its
 * extra privileges.
 */
#ifdef	_NOT_AVAILABLE
#define	_POSIX_SAVED_IDS	1
				/* saved set-user-ID and set-group-ID */
#endif

#define	_POSIX_VERSION			200112L
#define	_POSIX2_VERSION			200112L

/*
 * We support the posix_spawn() family of functions (unconditionally).
 */
#define	_POSIX_SPAWN			200809L

/* execution-time symbolic constants */

/*
 * POSIX options and option groups we unconditionally do or don't
 * implement.  Those options which are implemented (or not) entirely
 * in user mode are defined in <unistd.h>.  Please keep this list in
 * alphabetical order.
 *
 * Anything which is defined as zero below **must** have an
 * implementation for the corresponding sysconf() which is able to
 * determine conclusively whether or not the feature is supported.
 * Anything which is defined as other than -1 below **must** have
 * complete headers, types, and function declarations as specified by
 * the POSIX standard; however, if the relevant sysconf() function
 * returns -1, the functions may be stubbed out.
 */
					/* Advisory information */
#undef	_POSIX_ADVISORY_INFO
					/* asynchronous I/O is available */
#define	_POSIX_ASYNCHRONOUS_IO		200112L
					/* barriers */
#define	_POSIX_BARRIERS			200112L
					/* chown requires correct privileges */
#define	_POSIX_CHOWN_RESTRICTED		1
					/* clock selection */
#define	_POSIX_CLOCK_SELECTION		-1
					/* cputime clock */
#define	_POSIX_CPUTIME			200112L
					/* CPU type */
#undef	_POSIX_CPUTYPE
					/* file synchronization is available */
#define	_POSIX_FSYNC			1
					/* support IPv6 */
#define	_POSIX_IPV6			0
					/* job control is available */
#define	_POSIX_JOB_CONTROL		1
					/* memory mapped files */
#define	_POSIX_MAPPED_FILES		1
					/* memory locking whole address space */
#define	_POSIX_MEMLOCK			1
					/* memory locking address ranges */
#define	_POSIX_MEMLOCK_RANGE		1
					/* memory access protections */
#define	_POSIX_MEMORY_PROTECTION	1
					/* message passing is available */
#define	_POSIX_MESSAGE_PASSING		200112L
					/* monotonic clock */
#define	_POSIX_MONOTONIC_CLOCK		200112L
					/* too-long path comp generate errors */
#define	_POSIX_NO_TRUNC			1
					/* prioritized I/O */
#define	_POSIX_PRIORITIZED_IO		-1
					/* priority scheduling */
#define	_POSIX_PRIORITY_SCHEDULING	200112L
					/* raw sockets */
#define	_POSIX_RAW_SOCKETS		200112L
					/* read/write locks */
#define	_POSIX_READER_WRITER_LOCKS	200112L
					/* realtime signals */
#undef	_POSIX_REALTIME_SIGNALS
					/* regular expressions */
#define	_POSIX_REGEXP			1
					/* semaphores */
#define	_POSIX_SEMAPHORES		0
					/* shared memory objects */
#define	_POSIX_SHARED_MEMORY_OBJECTS	0
					/* shell */
#define	_POSIX_SHELL			1
					/* spin locks */
#define	_POSIX_SPIN_LOCKS		200112L
					/* sporadic server */
#undef	_POSIX_SPORADIC_SERVER
					/* synchronized I/O is available */
#define	_POSIX_SYNCHRONIZED_IO		1
					/* threads */
#define	_POSIX_THREADS			200112L
					/* pthread_attr for stack size */
#define	_POSIX_THREAD_ATTR_STACKSIZE	200112L
					/* pthread_attr for stack address */
#define	_POSIX_THREAD_ATTR_STACKADDR	200112L
					/* thread cputime clock */
#define	_POSIX_THREAD_CPUTIME		200112L
					/* _r functions */
#define	_POSIX_THREAD_PRIO_PROTECT	200112L
					/* PTHREAD_PRIO_PROTECT */
#define	_POSIX_THREAD_SAFE_FUNCTIONS	200112L
					/* timeouts */
#undef	_POSIX_TIMEOUTS
					/* timers */
#define	_POSIX_TIMERS			200112L
					/* typed memory objects */
#undef	_POSIX_TYPED_MEMORY_OBJECTS
					/* may disable terminal spec chars */
#define	_POSIX_VDISABLE			__CAST(unsigned char, '\377')

					/* C binding */
#define	_POSIX2_C_BIND			200112L

					/* XPG4.2 shared memory */
#define	_XOPEN_SHM			0

/* access function */
#define	F_OK		0	/* test for existence of file */
#define	X_OK		0x01	/* test for execute or search permission */
#define	W_OK		0x02	/* test for write permission */
#define	R_OK		0x04	/* test for read permission */

/* whence values for lseek(2) */
#define	SEEK_SET	0	/* set file offset to offset */
#define	SEEK_CUR	1	/* set file offset to current plus offset */
#define	SEEK_END	2	/* set file offset to EOF plus offset */

#if defined(_NETBSD_SOURCE)
/* whence values for lseek(2); renamed by POSIX 1003.1 */
#define	L_SET		SEEK_SET
#define	L_INCR		SEEK_CUR
#define	L_XTND		SEEK_END

/*
 * fsync_range values.
 *
 * Note the following flag values were chosen to not overlap
 * values for SEEK_XXX flags.  While not currently implemented,
 * it is possible to extend this call to respect SEEK_CUR and
 * SEEK_END offset addressing modes.
 */
#define	FDATASYNC	0x0010	/* sync data and minimal metadata */
#define	FFILESYNC	0x0020	/* sync data and metadata */
#define	FDISKSYNC	0x0040	/* flush disk caches after sync */
#endif

/* configurable pathname variables; use as argument to pathconf(3) */
#define	_PC_LINK_MAX		 1
#define	_PC_MAX_CANON		 2
#define	_PC_MAX_INPUT		 3
#define	_PC_NAME_MAX		 4
#define	_PC_PATH_MAX		 5
#define	_PC_PIPE_BUF		 6
#define	_PC_CHOWN_RESTRICTED	 7
#define	_PC_NO_TRUNC		 8
#define	_PC_VDISABLE		 9
#define	_PC_SYNC_IO		10
#define	_PC_FILESIZEBITS	11
#define	_PC_SYMLINK_MAX		12
#define	_PC_2_SYMLINKS		13
#define	_PC_ACL_EXTENDED	14

/* From OpenSolaris, used by SEEK_DATA/SEEK_HOLE. */
#define	_PC_MIN_HOLE_SIZE	15

#ifdef _NETBSD_SOURCE
#define _PC_ACL_PATH_MAX        16
#define _PC_ACL_NFS4            17
#endif

/* configurable system variables; use as argument to sysconf(3) */
/*
 * XXX The value of _SC_CLK_TCK is embedded in <time.h>.
 * XXX The value of _SC_PAGESIZE is embedded in <sys/shm.h>.
 */
#define	_SC_ARG_MAX		 1
#define	_SC_CHILD_MAX		 2
#define	_O_SC_CLK_TCK		 3 /* Old version, always 100 */
#define	_SC_NGROUPS_MAX		 4
#define	_SC_OPEN_MAX		 5
#define	_SC_JOB_CONTROL		 6
#define	_SC_SAVED_IDS		 7
#define	_SC_VERSION		 8
#define	_SC_BC_BASE_MAX		 9
#define	_SC_BC_DIM_MAX		10
#define	_SC_BC_SCALE_MAX	11
#define	_SC_BC_STRING_MAX	12
#define	_SC_COLL_WEIGHTS_MAX	13
#define	_SC_EXPR_NEST_MAX	14
#define	_SC_LINE_MAX		15
#define	_SC_RE_DUP_MAX		16
#define	_SC_2_VERSION		17
#define	_SC_2_C_BIND		18
#define	_SC_2_C_DEV		19
#define	_SC_2_CHAR_TERM		20
#define	_SC_2_FORT_DEV		21
#define	_SC_2_FORT_RUN		22
#define	_SC_2_LOCALEDEF		23
#define	_SC_2_SW_DEV		24
#define	_SC_2_UPE		25
#define	_SC_STREAM_MAX		26
#define	_SC_TZNAME_MAX		27
#define	_SC_PAGESIZE		28
#define	_SC_PAGE_SIZE		_SC_PAGESIZE	/* 1170 compatibility */
#define	_SC_FSYNC		29
#define	_SC_XOPEN_SHM		30
#define	_SC_SYNCHRONIZED_IO	31
#define	_SC_IOV_MAX		32
#define	_SC_MAPPED_FILES	33
#define	_SC_MEMLOCK		34
#define	_SC_MEMLOCK_RANGE	35
#define	_SC_MEMORY_PROTECTION	36
#define	_SC_LOGIN_NAME_MAX	37
#define	_SC_MONOTONIC_CLOCK	38
#define	_SC_CLK_TCK		39 /* New, variable version */
#define	_SC_ATEXIT_MAX		40
#define	_SC_THREADS		41
#define	_SC_SEMAPHORES		42
#define	_SC_BARRIERS		43
#define	_SC_TIMERS		44
#define	_SC_SPIN_LOCKS		45
#define	_SC_READER_WRITER_LOCKS	46
#define	_SC_GETGR_R_SIZE_MAX	47
#define	_SC_GETPW_R_SIZE_MAX	48
#define	_SC_CLOCK_SELECTION	49
#define	_SC_ASYNCHRONOUS_IO	50
#define	_SC_AIO_LISTIO_MAX	51
#define	_SC_AIO_MAX		52
#define	_SC_MESSAGE_PASSING	53
#define	_SC_MQ_OPEN_MAX		54
#define	_SC_MQ_PRIO_MAX		55
#define	_SC_PRIORITY_SCHEDULING	56
#define	_SC_THREAD_DESTRUCTOR_ITERATIONS 57
#define	_SC_THREAD_KEYS_MAX		58
#define	_SC_THREAD_STACK_MIN		59
#define	_SC_THREAD_THREADS_MAX		60
#define	_SC_THREAD_ATTR_STACKADDR	61
#define	_SC_THREAD_ATTR_STACKSIZE 	62
#define	_SC_THREAD_PRIORITY_SCHEDULING	63
#define	_SC_THREAD_PRIO_INHERIT 	64
#define	_SC_THREAD_PRIO_PROTECT		65
#define	_SC_THREAD_PROCESS_SHARED	66
#define	_SC_THREAD_SAFE_FUNCTIONS	67
#define	_SC_TTY_NAME_MAX		68
#define	_SC_HOST_NAME_MAX		69
#define	_SC_PASS_MAX			70
#define	_SC_REGEXP			71
#define	_SC_SHELL			72
#define	_SC_SYMLOOP_MAX			73

/* Actually, they are not supported or implemented yet */
#define	_SC_V6_ILP32_OFF32		74
#define	_SC_V6_ILP32_OFFBIG		75
#define	_SC_V6_LP64_OFF64		76
#define	_SC_V6_LPBIG_OFFBIG		77
#define	_SC_2_PBS			80
#define	_SC_2_PBS_ACCOUNTING		81
#define	_SC_2_PBS_CHECKPOINT		82
#define	_SC_2_PBS_LOCATE		83
#define	_SC_2_PBS_MESSAGE		84
#define	_SC_2_PBS_TRACK			85

/* These are implemented */
#define	_SC_SPAWN			86
#define	_SC_SHARED_MEMORY_OBJECTS	87

#define	_SC_TIMER_MAX			88
#define	_SC_SEM_NSEMS_MAX		89
#define	_SC_CPUTIME			90
#define	_SC_THREAD_CPUTIME		91
#define	_SC_DELAYTIMER_MAX		92
#define	_SC_SIGQUEUE_MAX		93
#define	_SC_REALTIME_SIGNALS		94
#define	_SC_RTSIG_MAX			95

/* Extensions found in Solaris and Linux. */
#define	_SC_PHYS_PAGES		121

#ifdef _NETBSD_SOURCE
/* Commonly provided sysconf() extensions */
#define	_SC_NPROCESSORS_CONF	1001
#define	_SC_NPROCESSORS_ONLN	1002
/* Native variables */
#define	_SC_SCHED_RT_TS		2001
#define	_SC_SCHED_PRI_MIN	2002
#define	_SC_SCHED_PRI_MAX	2003
#endif	/* _NETBSD_SOURCE */

/* configurable system strings */
#define	_CS_PATH		 1

#endif /* !_SYS_UNISTD_H_ */