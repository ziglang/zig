/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _LINUX_RESOURCE_H
#define _LINUX_RESOURCE_H

#include <linux/time.h>
#include <linux/types.h>

/*
 * Resource control/accounting header file for linux
 */

/*
 * Definition of struct rusage taken from BSD 4.3 Reno
 * 
 * We don't support all of these yet, but we might as well have them....
 * Otherwise, each time we add new items, programs which depend on this
 * structure will lose.  This reduces the chances of that happening.
 */
#define	RUSAGE_SELF	0
#define	RUSAGE_CHILDREN	(-1)
#define RUSAGE_BOTH	(-2)		/* sys_wait4() uses this */
#define	RUSAGE_THREAD	1		/* only the calling thread */

struct	rusage {
	struct __kernel_old_timeval ru_utime;	/* user time used */
	struct __kernel_old_timeval ru_stime;	/* system time used */
	__kernel_long_t	ru_maxrss;	/* maximum resident set size */
	__kernel_long_t	ru_ixrss;	/* integral shared memory size */
	__kernel_long_t	ru_idrss;	/* integral unshared data size */
	__kernel_long_t	ru_isrss;	/* integral unshared stack size */
	__kernel_long_t	ru_minflt;	/* page reclaims */
	__kernel_long_t	ru_majflt;	/* page faults */
	__kernel_long_t	ru_nswap;	/* swaps */
	__kernel_long_t	ru_inblock;	/* block input operations */
	__kernel_long_t	ru_oublock;	/* block output operations */
	__kernel_long_t	ru_msgsnd;	/* messages sent */
	__kernel_long_t	ru_msgrcv;	/* messages received */
	__kernel_long_t	ru_nsignals;	/* signals received */
	__kernel_long_t	ru_nvcsw;	/* voluntary context switches */
	__kernel_long_t	ru_nivcsw;	/* involuntary " */
};

struct rlimit {
	__kernel_ulong_t	rlim_cur;
	__kernel_ulong_t	rlim_max;
};

#define RLIM64_INFINITY		(~0ULL)

struct rlimit64 {
	__u64 rlim_cur;
	__u64 rlim_max;
};

#define	PRIO_MIN	(-20)
#define	PRIO_MAX	20

#define	PRIO_PROCESS	0
#define	PRIO_PGRP	1
#define	PRIO_USER	2

/*
 * Limit the stack by to some sane default: root can always
 * increase this limit if needed..  8MB seems reasonable.
 */
#define _STK_LIM	(8*1024*1024)

/*
 * Limit the amount of locked memory by some sane default:
 * root can always increase this limit if needed.
 *
 * The main use-cases are (1) preventing sensitive memory
 * from being swapped; (2) real-time operations; (3) via
 * IOURING_REGISTER_BUFFERS.
 *
 * The first two don't need much. The latter will take as
 * much as it can get. 8MB is a reasonably sane default.
 */
#define MLOCK_LIMIT	(8*1024*1024)

/*
 * Due to binary compatibility, the actual resource numbers
 * may be different for different linux versions..
 */
#include <asm/resource.h>


#endif /* _LINUX_RESOURCE_H */