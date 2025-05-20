/*	$NetBSD: sysctl.h,v 1.236 2021/09/16 22:47:29 christos Exp $	*/

/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Mike Karels at Berkeley Software Design, Inc.
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
 *	@(#)sysctl.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _SYS_SYSCTL_H_
#define	_SYS_SYSCTL_H_

#include <sys/param.h> /* precautionary upon removal from ucred.h */
#include <sys/proc.h>  /* Needed for things like P_ZOMBIE() and LW_SINTR */
#include <uvm/uvm_param.h>

#if defined(_KERNEL) || defined(_KMEMUSER)
/*
 * These are for the eproc structure defined below.
 */
#include <sys/time.h>
#include <sys/ucred.h>
#include <sys/ucontext.h>
#include <sys/mallocvar.h>
#include <uvm/uvm_extern.h>
#endif


/* For offsetof() */
#if defined(_KERNEL) || defined(_STANDALONE)
#include <sys/systm.h>
#else
#include <stddef.h>
#include <stdbool.h>
#endif

/*
 * Definitions for sysctl call.  The sysctl call uses a hierarchical name
 * for objects that can be examined or modified.  The name is expressed as
 * a sequence of integers.  Like a file path name, the meaning of each
 * component depends on its place in the hierarchy.  The top-level and kern
 * identifiers are defined here, and other identifiers are defined in the
 * respective subsystem header files.
 */

struct sysctlnode;

#define	CTL_MAXNAME	12	/* largest number of components supported */
#define SYSCTL_NAMELEN	32	/* longest name allowed for a node */

#define CREATE_BASE	(1024)	/* start of dynamic mib allocation */
#define SYSCTL_DEFSIZE	8	/* initial size of a child set */

/*
 * Each subsystem defined by sysctl defines a list of variables
 * for that subsystem. Each name is either a node with further
 * levels defined below it, or it is a leaf of some particular
 * type given below. Each sysctl level defines a set of name/type
 * pairs to be used by sysctl(1) in manipulating the subsystem.
 */
struct ctlname {
	const char *ctl_name;	/* subsystem name */
	int	ctl_type;	/* type of name */
};
#define	CTLTYPE_NODE	1	/* name is a node */
#define	CTLTYPE_INT	2	/* name describes an integer */
#define	CTLTYPE_STRING	3	/* name describes a string */
#define	CTLTYPE_QUAD	4	/* name describes a 64-bit number */
#define	CTLTYPE_STRUCT	5	/* name describes a structure */
#define	CTLTYPE_BOOL	6	/* name describes a bool */

#ifdef _LP64
#define	CTLTYPE_LONG	CTLTYPE_QUAD
#else
#define	CTLTYPE_LONG	CTLTYPE_INT
#endif

/*
 * Flags that apply to each node, governing access and other features
 */
#define CTLFLAG_READONLY	0x00000000
/* #define CTLFLAG_UNUSED1		0x00000010 */
/* #define CTLFLAG_UNUSED2		0x00000020 */
/* #define CTLFLAG_READ*	0x00000040 */
#define CTLFLAG_READWRITE	0x00000070
#define CTLFLAG_ANYWRITE	0x00000080
#define CTLFLAG_PRIVATE		0x00000100
#define CTLFLAG_PERMANENT	0x00000200
#define CTLFLAG_OWNDATA		0x00000400
#define CTLFLAG_IMMEDIATE	0x00000800
#define CTLFLAG_HEX		0x00001000
#define CTLFLAG_ROOT		0x00002000
#define CTLFLAG_ANYNUMBER	0x00004000
#define CTLFLAG_HIDDEN		0x00008000
#define CTLFLAG_ALIAS		0x00010000
#define CTLFLAG_MMAP		0x00020000
#define CTLFLAG_OWNDESC		0x00040000
#define CTLFLAG_UNSIGNED	0x00080000

/*
 * sysctl API version
 */
#define SYSCTL_VERS_MASK	0xff000000
#define SYSCTL_VERS_0		0x00000000
#define SYSCTL_VERS_1		0x01000000
#define SYSCTL_VERSION		SYSCTL_VERS_1
#define SYSCTL_VERS(f)		((f) & SYSCTL_VERS_MASK)

/*
 * Flags that can be set by a create request from user-space
 */
#define SYSCTL_USERFLAGS	(CTLFLAG_READWRITE|\
				CTLFLAG_ANYWRITE|\
				CTLFLAG_PRIVATE|\
				CTLFLAG_OWNDATA|\
				CTLFLAG_IMMEDIATE|\
				CTLFLAG_HEX|\
				CTLFLAG_HIDDEN)

/*
 * Accessor macros
 */
#define SYSCTL_TYPEMASK		0x0000000f
#define SYSCTL_TYPE(x)		((x) & SYSCTL_TYPEMASK)
#define SYSCTL_FLAGMASK		0x00fffff0
#define SYSCTL_FLAGS(x)		((x) & SYSCTL_FLAGMASK)

/*
 * Meta-identifiers
 */
#define CTL_EOL		(-1)		/* end of createv/destroyv list */
#define CTL_QUERY	(-2)		/* enumerates children of a node */
#define CTL_CREATE	(-3)		/* node create request */
#define CTL_CREATESYM	(-4)		/* node create request with symbol */
#define CTL_DESTROY	(-5)		/* node destroy request */
#define CTL_MMAP	(-6)		/* mmap request */
#define CTL_DESCRIBE	(-7)		/* get node descriptions */

/*
 * Top-level identifiers
 */
#define	CTL_UNSPEC	0		/* unused */
#define	CTL_KERN	1		/* "high kernel": proc, limits */
#define	CTL_VM		2		/* virtual memory */
#define	CTL_VFS		3		/* file system, mount type is next */
#define	CTL_NET		4		/* network, see socket.h */
#define	CTL_DEBUG	5		/* debugging parameters */
#define	CTL_HW		6		/* generic CPU/io */
#define	CTL_MACHDEP	7		/* machine dependent */
#define	CTL_USER	8		/* user-level */
#define	CTL_DDB		9		/* in-kernel debugger */
#define	CTL_PROC	10		/* per-proc attr */
#define	CTL_VENDOR	11		/* vendor-specific data */
#define	CTL_EMUL	12		/* emulation-specific data */
#define	CTL_SECURITY	13		/* security */

/*
 * The "vendor" toplevel name is to be used by vendors who wish to
 * have their own private MIB tree. If you do that, please use
 * vendor.<yourname>.*
 */

/*
 * CTL_KERN identifiers
 */
#define	KERN_OSTYPE	 	 1	/* string: system version */
#define	KERN_OSRELEASE	 	 2	/* string: system release */
#define	KERN_OSREV	 	 3	/* int: system revision */
#define	KERN_VERSION	 	 4	/* string: compile time info */
#define	KERN_MAXVNODES	 	 5	/* int: max vnodes */
#define	KERN_MAXPROC	 	 6	/* int: max processes */
#define	KERN_MAXFILES	 	 7	/* int: max open files */
#define	KERN_ARGMAX	 	 8	/* int: max arguments to exec */
#define	KERN_SECURELVL	 	 9	/* int: system security level */
#define	KERN_HOSTNAME		10	/* string: hostname */
#define	KERN_HOSTID		11	/* int: host identifier */
#define	KERN_CLOCKRATE		12	/* struct: struct clockinfo */
#define	KERN_VNODE		13	/* struct: vnode structures */
#define	KERN_PROC		14	/* struct: process entries */
#define	KERN_FILE		15	/* struct: file entries */
#define	KERN_PROF		16	/* node: kernel profiling info */
#define	KERN_POSIX1		17	/* int: POSIX.1 version */
#define	KERN_NGROUPS		18	/* int: # of supplemental group ids */
#define	KERN_JOB_CONTROL	19	/* int: is job control available */
#define	KERN_SAVED_IDS		20	/* int: saved set-user/group-ID */
#define	KERN_OBOOTTIME		21	/* struct: time kernel was booted */
#define	KERN_DOMAINNAME		22	/* string: (YP) domainname */
#define	KERN_MAXPARTITIONS	23	/* int: number of partitions/disk */
#define	KERN_RAWPARTITION	24	/* int: raw partition number */
#define	KERN_NTPTIME		25	/* struct: extended-precision time */
#define	KERN_TIMEX		26	/* struct: ntp timekeeping state */
#define	KERN_AUTONICETIME	27	/* int: proc time before autonice */
#define	KERN_AUTONICEVAL	28	/* int: auto nice value */
#define	KERN_RTC_OFFSET		29	/* int: offset of rtc from gmt */
#define	KERN_ROOT_DEVICE	30	/* string: root device */
#define	KERN_MSGBUFSIZE		31	/* int: max # of chars in msg buffer */
#define	KERN_FSYNC		32	/* int: file synchronization support */
#define	KERN_OLDSYSVMSG		33	/* old: SysV message queue support */
#define	KERN_OLDSYSVSEM		34	/* old: SysV semaphore support */
#define	KERN_OLDSYSVSHM		35	/* old: SysV shared memory support */
#define	KERN_OLDSHORTCORENAME	36	/* old, unimplemented */
#define	KERN_SYNCHRONIZED_IO	37	/* int: POSIX synchronized I/O */
#define	KERN_IOV_MAX		38	/* int: max iovec's for readv(2) etc. */
#define	KERN_MBUF		39	/* node: mbuf parameters */
#define	KERN_MAPPED_FILES	40	/* int: POSIX memory mapped files */
#define	KERN_MEMLOCK		41	/* int: POSIX memory locking */
#define	KERN_MEMLOCK_RANGE	42	/* int: POSIX memory range locking */
#define	KERN_MEMORY_PROTECTION	43	/* int: POSIX memory protections */
#define	KERN_LOGIN_NAME_MAX	44	/* int: max length login name + NUL */
#define	KERN_DEFCORENAME	45	/* old: sort core name format */
#define	KERN_LOGSIGEXIT		46	/* int: log signaled processes */
#define	KERN_PROC2		47	/* struct: process entries */
#define	KERN_PROC_ARGS		48	/* struct: process argv/env */
#define	KERN_FSCALE		49	/* int: fixpt FSCALE */
#define	KERN_CCPU		50	/* old: fixpt ccpu */
#define	KERN_CP_TIME		51	/* struct: CPU time counters */
#define	KERN_OLDSYSVIPC_INFO	52	/* old: number of valid kern ids */
#define	KERN_MSGBUF		53	/* kernel message buffer */
#define	KERN_CONSDEV		54	/* dev_t: console terminal device */
#define	KERN_MAXPTYS		55	/* int: maximum number of ptys */
#define	KERN_PIPE		56	/* node: pipe limits */
#define	KERN_MAXPHYS		57	/* int: kernel value of MAXPHYS */
#define	KERN_SBMAX		58	/* int: max socket buffer size */
#define	KERN_TKSTAT		59	/* tty in/out counters */
#define	KERN_MONOTONIC_CLOCK	60	/* int: POSIX monotonic clock */
#define	KERN_URND		61	/* int: random integer from urandom */
#define	KERN_LABELSECTOR	62	/* int: disklabel sector */
#define	KERN_LABELOFFSET	63	/* int: offset of label within sector */
#define	KERN_LWP		64	/* struct: lwp entries */
#define	KERN_FORKFSLEEP		65	/* int: sleep length on failed fork */
#define	KERN_POSIX_THREADS	66	/* int: POSIX Threads option */
#define	KERN_POSIX_SEMAPHORES	67	/* int: POSIX Semaphores option */
#define	KERN_POSIX_BARRIERS	68	/* int: POSIX Barriers option */
#define	KERN_POSIX_TIMERS	69	/* int: POSIX Timers option */
#define	KERN_POSIX_SPIN_LOCKS	70	/* int: POSIX Spin Locks option */
#define	KERN_POSIX_READER_WRITER_LOCKS 71 /* int: POSIX R/W Locks option */
#define	KERN_DUMP_ON_PANIC	72	/* int: dump on panic */
#define	KERN_SOMAXKVA		73	/* int: max socket kernel virtual mem */
#define	KERN_ROOT_PARTITION	74	/* int: root partition */
#define	KERN_DRIVERS		75	/* struct: driver names and majors #s */
#define	KERN_BUF		76	/* struct: buffers */
#define	KERN_FILE2		77	/* struct: file entries */
#define	KERN_VERIEXEC		78	/* node: verified exec */
#define	KERN_CP_ID		79	/* struct: cpu id numbers */
#define	KERN_HARDCLOCK_TICKS	80	/* int: number of hardclock ticks */
#define	KERN_ARND		81	/* void *buf, size_t siz random */
#define	KERN_SYSVIPC		82	/* node: SysV IPC parameters */
#define	KERN_BOOTTIME		83	/* struct: time kernel was booted */
#define	KERN_EVCNT		84	/* struct: evcnts */
#define	KERN_SOFIXEDBUF		85	/* bool: fixed socket buffer sizes */

/*
 *  KERN_CLOCKRATE structure
 */
struct clockinfo {
	int	hz;		/* clock frequency */
	int	tick;		/* micro-seconds per hz tick */
	int	tickadj;	/* clock skew rate for adjtime() */
	int	stathz;		/* statistics clock frequency */
	int	profhz;		/* profiling clock frequency */
};

/*
 * KERN_PROC subtypes
 */
#define	KERN_PROC_ALL		 0	/* everything */
#define	KERN_PROC_PID		 1	/* by process id */
#define	KERN_PROC_PGRP		 2	/* by process group id */
#define	KERN_PROC_SESSION	 3	/* by session of pid */
#define	KERN_PROC_TTY		 4	/* by controlling tty */
#define	KERN_PROC_UID		 5	/* by effective uid */
#define	KERN_PROC_RUID		 6	/* by real uid */
#define	KERN_PROC_GID		 7	/* by effective gid */
#define	KERN_PROC_RGID		 8	/* by real gid */

/*
 * KERN_PROC_TTY sub-subtypes
 */
#define	KERN_PROC_TTY_NODEV	NODEV		/* no controlling tty */
#define	KERN_PROC_TTY_REVOKE	((dev_t)-2)	/* revoked tty */

struct ki_pcred {
	void		*p_pad;
	uid_t		p_ruid;		/* Real user id */
	uid_t		p_svuid;	/* Saved effective user id */
	gid_t		p_rgid;		/* Real group id */
	gid_t		p_svgid;	/* Saved effective group id */
	int		p_refcnt;	/* Number of references */
};

struct ki_ucred {
	uint32_t	cr_ref;			/* reference count */
	uid_t		cr_uid;			/* effective user id */
	gid_t		cr_gid;			/* effective group id */
	uint32_t	cr_ngroups;		/* number of groups */
	gid_t		cr_groups[NGROUPS];	/* groups */
};

#if defined(_KERNEL) || defined(_KMEMUSER)

struct	eproc {
	struct	proc *e_paddr;		/* address of proc */
	struct	session *e_sess;	/* session pointer */
	struct	ki_pcred e_pcred;	/* process credentials */
	struct	ki_ucred e_ucred;	/* current credentials */
	struct	vmspace e_vm;		/* address space */
	pid_t	e_ppid;			/* parent process id */
	pid_t	e_pgid;			/* process group id */
	short	e_jobc;			/* job control counter */
	uint32_t e_tdev;		/* XXX: controlling tty dev */
	pid_t	e_tpgid;		/* tty process group id */
	struct	session *e_tsess;	/* tty session pointer */
#define	WMESGLEN	8
	char	e_wmesg[WMESGLEN];	/* wchan message */
	segsz_t e_xsize;		/* text size */
	short	e_xrssize;		/* text rss */
	short	e_xccount;		/* text references */
	short	e_xswrss;
	long	e_flag;			/* see p_eflag  below */
	char	e_login[MAXLOGNAME];	/* setlogin() name */
	pid_t	e_sid;			/* session id */
	long	e_spare[3];
};

/*
 * KERN_PROC subtype ops return arrays of augmented proc structures:
 */
struct kinfo_proc {
	struct	proc kp_proc;			/* proc structure */
	struct	eproc kp_eproc;			/* eproc structure */
};
#endif /* defined(_KERNEL) || defined(_KMEMUSER) */

/*
 * Convert pointer to 64 bit unsigned integer for struct
 * kinfo_proc2, etc.
 */
#define PTRTOUINT64(p) ((uint64_t)(uintptr_t)(p))
#define UINT64TOPTR(u) ((void *)(uintptr_t)(u))

/*
 * KERN_PROC2 subtype ops return arrays of relatively fixed size
 * structures of process info.   Use 8 byte alignment, and new
 * elements should only be added to the end of this structure so
 * binary compatibility can be preserved.
 */
#define	KI_NGROUPS	16
#define	KI_MAXCOMLEN	24	/* extra for 8 byte alignment */
#define	KI_WMESGLEN	8
#define	KI_MAXLOGNAME	24	/* extra for 8 byte alignment */
#define	KI_MAXEMULLEN	16
#define	KI_LNAMELEN	20	/* extra 4 for alignment */

#define KI_NOCPU	(~(uint64_t)0)

typedef struct {
	uint32_t	__bits[4];
} ki_sigset_t;

struct kinfo_proc2 {
	uint64_t p_forw;		/* PTR: linked run/sleep queue. */
	uint64_t p_back;
	uint64_t p_paddr;		/* PTR: address of proc */

	uint64_t p_addr;		/* PTR: Kernel virtual addr of u-area */
	uint64_t p_fd;			/* PTR: Ptr to open files structure. */
	uint64_t p_cwdi;		/* PTR: cdir/rdir/cmask info */
	uint64_t p_stats;		/* PTR: Accounting/statistics */
	uint64_t p_limit;		/* PTR: Process limits. */
	uint64_t p_vmspace;		/* PTR: Address space. */
	uint64_t p_sigacts;		/* PTR: Signal actions, state */
	uint64_t p_sess;		/* PTR: session pointer */
	uint64_t p_tsess;		/* PTR: tty session pointer */
	uint64_t p_ru;			/* PTR: Exit information. XXX */

	int32_t	p_eflag;		/* LONG: extra kinfo_proc2 flags */
#define	EPROC_CTTY	0x01	/* controlling tty vnode active */
#define	EPROC_SLEADER	0x02	/* session leader */
	int32_t	p_exitsig;		/* INT: signal to sent to parent on exit */
	int32_t	p_flag;			/* INT: P_* flags. */

	int32_t	p_pid;			/* PID_T: Process identifier. */
	int32_t	p_ppid;			/* PID_T: Parent process id */
	int32_t	p_sid;			/* PID_T: session id */
	int32_t	p__pgid;		/* PID_T: process group id */
					/* XXX: <sys/proc.h> hijacks p_pgid */
	int32_t	p_tpgid;		/* PID_T: tty process group id */

	uint32_t p_uid;			/* UID_T: effective user id */
	uint32_t p_ruid;		/* UID_T: real user id */
	uint32_t p_gid;			/* GID_T: effective group id */
	uint32_t p_rgid;		/* GID_T: real group id */

	uint32_t p_groups[KI_NGROUPS];	/* GID_T: groups */
	int16_t	p_ngroups;		/* SHORT: number of groups */

	int16_t	p_jobc;			/* SHORT: job control counter */
	uint32_t p_tdev;		/* XXX: DEV_T: controlling tty dev */

	uint32_t p_estcpu;		/* U_INT: Time averaged value of p_cpticks. */
	uint32_t p_rtime_sec;		/* STRUCT TIMEVAL: Real time. */
	uint32_t p_rtime_usec;		/* STRUCT TIMEVAL: Real time. */
	int32_t	p_cpticks;		/* INT: Ticks of CPU time. */
	uint32_t p_pctcpu;		/* FIXPT_T: %cpu for this process during p_swtime */
	uint32_t p_swtime;		/* U_INT: Time swapped in or out. */
	uint32_t p_slptime;		/* U_INT: Time since last blocked. */
	int32_t	p_schedflags;		/* INT: PSCHED_* flags */

	uint64_t p_uticks;		/* U_QUAD_T: Statclock hits in user mode. */
	uint64_t p_sticks;		/* U_QUAD_T: Statclock hits in system mode. */
	uint64_t p_iticks;		/* U_QUAD_T: Statclock hits processing intr. */

	uint64_t p_tracep;		/* PTR: Trace to vnode or file */
	int32_t	p_traceflag;		/* INT: Kernel trace points. */

	int32_t	p_holdcnt;              /* INT: If non-zero, don't swap. */

	ki_sigset_t p_siglist;		/* SIGSET_T: Signals arrived but not delivered. */
	ki_sigset_t p_sigmask;		/* SIGSET_T: Current signal mask. */
	ki_sigset_t p_sigignore;	/* SIGSET_T: Signals being ignored. */
	ki_sigset_t p_sigcatch;		/* SIGSET_T: Signals being caught by user. */

	int8_t	p_stat;			/* CHAR: S* process status (from LWP). */
	uint8_t p_priority;		/* U_CHAR: Process priority. */
	uint8_t p_usrpri;		/* U_CHAR: User-priority based on p_cpu and p_nice. */
	uint8_t p_nice;			/* U_CHAR: Process "nice" value. */

	uint16_t p_xstat;		/* U_SHORT: Exit status for wait; also stop signal. */
	uint16_t p_acflag;		/* U_SHORT: Accounting flags. */

	char	p_comm[KI_MAXCOMLEN];

	char	p_wmesg[KI_WMESGLEN];	/* wchan message */
	uint64_t p_wchan;		/* PTR: sleep address. */

	char	p_login[KI_MAXLOGNAME];	/* setlogin() name */

	int32_t	p_vm_rssize;		/* SEGSZ_T: current resident set size in pages */
	int32_t	p_vm_tsize;		/* SEGSZ_T: text size (pages) */
	int32_t	p_vm_dsize;		/* SEGSZ_T: data size (pages) */
	int32_t	p_vm_ssize;		/* SEGSZ_T: stack size (pages) */

	int64_t	p_uvalid;		/* CHAR: following p_u* parameters are valid */
					/* XXX 64 bits for alignment */
	uint32_t p_ustart_sec;		/* STRUCT TIMEVAL: starting time. */
	uint32_t p_ustart_usec;		/* STRUCT TIMEVAL: starting time. */

	uint32_t p_uutime_sec;		/* STRUCT TIMEVAL: user time. */
	uint32_t p_uutime_usec;		/* STRUCT TIMEVAL: user time. */
	uint32_t p_ustime_sec;		/* STRUCT TIMEVAL: system time. */
	uint32_t p_ustime_usec;		/* STRUCT TIMEVAL: system time. */

	uint64_t p_uru_maxrss;		/* LONG: max resident set size. */
	uint64_t p_uru_ixrss;		/* LONG: integral shared memory size. */
	uint64_t p_uru_idrss;		/* LONG: integral unshared data ". */
	uint64_t p_uru_isrss;		/* LONG: integral unshared stack ". */
	uint64_t p_uru_minflt;		/* LONG: page reclaims. */
	uint64_t p_uru_majflt;		/* LONG: page faults. */
	uint64_t p_uru_nswap;		/* LONG: swaps. */
	uint64_t p_uru_inblock;		/* LONG: block input operations. */
	uint64_t p_uru_oublock;		/* LONG: block output operations. */
	uint64_t p_uru_msgsnd;		/* LONG: messages sent. */
	uint64_t p_uru_msgrcv;		/* LONG: messages received. */
	uint64_t p_uru_nsignals;	/* LONG: signals received. */
	uint64_t p_uru_nvcsw;		/* LONG: voluntary context switches. */
	uint64_t p_uru_nivcsw;		/* LONG: involuntary ". */

	uint32_t p_uctime_sec;		/* STRUCT TIMEVAL: child u+s time. */
	uint32_t p_uctime_usec;		/* STRUCT TIMEVAL: child u+s time. */
	uint64_t p_cpuid;		/* LONG: CPU id */
	uint64_t p_realflag;	       	/* INT: P_* flags (not including LWPs). */
	uint64_t p_nlwps;		/* LONG: Number of LWPs */
	uint64_t p_nrlwps;		/* LONG: Number of running LWPs */
	uint64_t p_realstat;		/* LONG: non-LWP process status */
	uint32_t p_svuid;		/* UID_T: saved user id */
	uint32_t p_svgid;		/* GID_T: saved group id */
	char p_ename[KI_MAXEMULLEN];	/* emulation name */
	int64_t	p_vm_vsize;		/* SEGSZ_T: total map size (pages) */
	int64_t	p_vm_msize;		/* SEGSZ_T: stack-adjusted map size (pages) */
};

/*
 * Compat flags for kinfo_proc, kinfo_proc2.  Not guaranteed to be stable.
 * Some of them used to be shared with LWP flags.
 * XXXAD Trim to the minimum necessary...
 */

#define	P_ADVLOCK		0x00000001
#define	P_CONTROLT		0x00000002
#define	L_INMEM			0x00000004
#define	P_INMEM		     /* 0x00000004 */	L_INMEM
#define	P_NOCLDSTOP		0x00000008
#define	P_PPWAIT		0x00000010
#define	P_PROFIL		0x00000020
#define	L_SELECT		0x00000040
#define	P_SELECT	     /* 0x00000040 */	L_SELECT
#define	L_SINTR			0x00000080
#define	P_SINTR		     /* 0x00000080 */	L_SINTR
#define	P_SUGID			0x00000100
#define	L_SYSTEM	     	0x00000200
#define	P_SYSTEM	     /*	0x00000200 */	L_SYSTEM
#define	L_SA			0x00000400
#define	P_SA		     /* 0x00000400 */	L_SA
#define	P_TRACED		0x00000800
#define	P_WAITED		0x00001000
#define	P_WEXIT			0x00002000
#define	P_EXEC			0x00004000
#define	P_OWEUPC		0x00008000
#define	P_NOCLDWAIT		0x00020000
#define	P_32			0x00040000
#define	P_CLDSIGIGN		0x00080000
#define	P_SYSTRACE		0x00200000
#define	P_CHTRACED		0x00400000
#define	P_STOPFORK		0x00800000
#define	P_STOPEXEC		0x01000000
#define	P_STOPEXIT		0x02000000
#define	P_SYSCALL		0x04000000

/*
 * LWP compat flags.
 */
#define	L_DETACHED		0x00800000

#define	__SYSCTL_PROC_FLAG_BITS \
	"\20" \
	"\1ADVLOCK" \
	"\2CONTROLT" \
	"\3INMEM" \
	"\4NOCLDSTOP" \
	"\5PPWAIT" \
	"\6PROFIL" \
	"\7SELECT" \
	"\10SINTR" \
	"\11SUGID" \
	"\12SYSTEM" \
	"\13SA" \
	"\14TRACED" \
	"\15WAITED" \
	"\16WEXIT" \
	"\17EXEC" \
	"\20OWEUPC" \
	"\22NOCLDWAIT" \
	"\23P32" \
	"\24CLDSIGIGN" \
	"\26SYSTRACE" \
	"\27CHTRACED" \
	"\30STOPFORK" \
	"\31STOPEXEC" \
	"\32STOPEXIT" \
	"\33SYSCALL"

/*
 * KERN_LWP structure. See notes on KERN_PROC2 about adding elements.
 */
struct kinfo_lwp {
	uint64_t l_forw;		/* PTR: linked run/sleep queue. */
	uint64_t l_back;
	uint64_t l_laddr;		/* PTR: Address of LWP */
	uint64_t l_addr;		/* PTR: Kernel virtual addr of u-area */
	int32_t	l_lid;			/* LWPID_T: LWP identifier */
	int32_t	l_flag;			/* INT: L_* flags. */
	uint32_t l_swtime;		/* U_INT: Time swapped in or out. */
	uint32_t l_slptime;		/* U_INT: Time since last blocked. */
	int32_t	l_schedflags;		/* INT: PSCHED_* flags */
	int32_t	l_holdcnt;              /* INT: If non-zero, don't swap. */
	uint8_t l_priority;		/* U_CHAR: Process priority. */
	uint8_t l_usrpri;		/* U_CHAR: User-priority based on l_cpu and p_nice. */
	int8_t	l_stat;			/* CHAR: S* process status. */
	int8_t	l_pad1;			/* fill out to 4-byte boundary */
	int32_t	l_pad2;			/* .. and then to an 8-byte boundary */
	char	l_wmesg[KI_WMESGLEN];	/* wchan message */
	uint64_t l_wchan;		/* PTR: sleep address. */
	uint64_t l_cpuid;		/* LONG: CPU id */
	uint32_t l_rtime_sec;		/* STRUCT TIMEVAL: Real time. */
	uint32_t l_rtime_usec;		/* STRUCT TIMEVAL: Real time. */
	uint32_t l_cpticks;		/* INT: ticks during l_swtime */
	uint32_t l_pctcpu;		/* FIXPT_T: cpu usage for ps */
	uint32_t l_pid;			/* PID_T: process identifier */
	char	l_name[KI_LNAMELEN];	/* CHAR[]: name, may be empty */
};

/*
 * KERN_PROC_ARGS subtypes
 */
#define	KERN_PROC_ARGV		1	/* argv */
#define	KERN_PROC_NARGV		2	/* number of strings in above */
#define	KERN_PROC_ENV		3	/* environ */
#define	KERN_PROC_NENV		4	/* number of strings in above */
#define	KERN_PROC_PATHNAME 	5	/* path to executable */
#define	KERN_PROC_CWD 		6	/* current working dir */

/*
 * KERN_SYSVIPC subtypes
 */
#define	KERN_SYSVIPC_INFO	1	/* struct: number of valid kern ids */
#define	KERN_SYSVIPC_MSG	2	/* int: SysV message queue support */
#define	KERN_SYSVIPC_SEM	3	/* int: SysV semaphore support */
#define	KERN_SYSVIPC_SHM	4	/* int: SysV shared memory support */
#define	KERN_SYSVIPC_SHMMAX	5	/* int: max shared memory segment size (bytes) */
#define	KERN_SYSVIPC_SHMMNI	6	/* int: max number of shared memory identifiers */
#define	KERN_SYSVIPC_SHMSEG	7	/* int: max shared memory segments per process */
#define	KERN_SYSVIPC_SHMMAXPGS	8	/* int: max amount of shared memory (pages) */
#define	KERN_SYSVIPC_SHMUSEPHYS	9	/* int: physical memory usage */

/*
 * KERN_SYSVIPC_INFO subtypes
 */
/* KERN_SYSVIPC_OMSG_INFO		1	*/
/* KERN_SYSVIPC_OSEM_INFO		2	*/
/* KERN_SYSVIPC_OSHM_INFO		3	*/
#define	KERN_SYSVIPC_MSG_INFO		4	/* msginfo and msgid_ds */
#define	KERN_SYSVIPC_SEM_INFO		5	/* seminfo and semid_ds */
#define	KERN_SYSVIPC_SHM_INFO		6	/* shminfo and shmid_ds */

/*
 * tty counter sysctl variables
 */
#define	KERN_TKSTAT_NIN			1	/* total input character */
#define	KERN_TKSTAT_NOUT		2	/* total output character */
#define	KERN_TKSTAT_CANCC		3	/* canonical input character */
#define	KERN_TKSTAT_RAWCC		4	/* raw input character */

/*
 * kern.drivers returns an array of these.
 */

struct kinfo_drivers {
	devmajor_t	d_cmajor;
	devmajor_t	d_bmajor;
	char		d_name[24];
};

/*
 * KERN_BUF subtypes, like KERN_PROC2, where the four following mib
 * entries specify "which type of buf", "which particular buf",
 * "sizeof buf", and "how many".  Currently, only "all buf" is
 * defined.
 */
#define	KERN_BUF_ALL	0		/* all buffers */

/*
 * kern.buf returns an array of these structures, which are designed
 * both to be immune to 32/64 bit emulation issues and to provide
 * backwards compatibility.  Note that the order here differs slightly
 * from the real struct buf in order to achieve proper 64 bit
 * alignment.
 */
struct buf_sysctl {
	uint32_t b_flags;	/* LONG: B_* flags */
	int32_t  b_error;	/* INT: Errno value */
	int32_t  b_prio;	/* INT: Hint for buffer queue discipline */
	uint32_t b_dev;		/* DEV_T: Device associated with buffer */
	uint64_t b_bufsize;	/* LONG: Allocated buffer size */
	uint64_t b_bcount;	/* LONG: Valid bytes in buffer */
	uint64_t b_resid;	/* LONG: Remaining I/O */
	uint64_t b_addr;	/* CADDR_T: Memory, superblocks, indirect... */
	uint64_t b_blkno;	/* DADDR_T: Underlying physical block number */
	uint64_t b_rawblkno;	/* DADDR_T: Raw underlying physical block */
	uint64_t b_iodone;	/* PTR: Function called upon completion */
	uint64_t b_proc;	/* PTR: Associated proc if B_PHYS set */
	uint64_t b_vp;		/* PTR: File vnode */
	uint64_t b_saveaddr;	/* PTR: Original b_addr for physio */
	uint64_t b_lblkno;	/* DADDR_T: Logical block number */
};

#define	KERN_BUFSLOP	20

/*
 * kern.file2 returns an array of these structures, which are designed
 * both to be immune to 32/64 bit emulation issues and to
 * provide backwards compatibility.  The order differs slightly from
 * that of the real struct file, and some fields are taken from other
 * structures (struct vnode, struct proc) in order to make the file
 * information more useful.
 */
struct kinfo_file {
	uint64_t	ki_fileaddr;	/* PTR: address of struct file */
	uint32_t	ki_flag;	/* INT: flags (see fcntl.h) */
	uint32_t	ki_iflags;	/* INT: internal flags */
	uint32_t	ki_ftype;	/* INT: descriptor type */
	uint32_t	ki_count;	/* UINT: reference count */
	uint32_t	ki_msgcount;	/* UINT: references from msg queue */
	uint32_t	ki_usecount;	/* INT: number active users */
	uint64_t	ki_fucred;	/* PTR: creds for descriptor */
	uint32_t	ki_fuid;	/* UID_T: descriptor credentials */
	uint32_t	ki_fgid;	/* GID_T: descriptor credentials */
	uint64_t	ki_fops;	/* PTR: address of fileops */
	uint64_t	ki_foffset;	/* OFF_T: offset */
	uint64_t	ki_fdata;	/* PTR: descriptor data */

	/* vnode information to glue this file to something */
	uint64_t	ki_vun;		/* PTR: socket, specinfo, etc */
	uint64_t	ki_vsize;	/* OFF_T: size of file */
	uint32_t	ki_vtype;	/* ENUM: vnode type */
	uint32_t	ki_vtag;	/* ENUM: type of underlying data */
	uint64_t	ki_vdata;	/* PTR: private data for fs */

	/* process information when retrieved via KERN_FILE_BYPID */
	uint32_t	ki_pid;		/* PID_T: process id */
	int32_t		ki_fd;		/* INT: descriptor number */
	uint32_t	ki_ofileflags;	/* CHAR: open file flags */
	uint32_t	_ki_padto64bits;
};

#define	KERN_FILE_BYFILE	1
#define	KERN_FILE_BYPID		2
#define	KERN_FILESLOP		10

/*
 * kern.evcnt returns an array of these structures, which are designed both to
 * be immune to 32/64 bit emulation issues.  Note that the struct here differs
 * from the real struct evcnt but contains the same information in order to
 * accommodate sysctl.
 */
struct evcnt_sysctl {
	uint64_t	ev_count;		/* current count */
	uint64_t	ev_addr;		/* kernel address of evcnt */
	uint64_t	ev_parent;		/* kernel address of parent */
	uint8_t		ev_type;		/* EVCNT_TRAP_* */
	uint8_t		ev_grouplen;		/* length of group with NUL */
	uint8_t		ev_namelen;		/* length of name with NUL */
	uint8_t		ev_len;			/* multiply by 8 */
	/*
	 * Now the group and name strings follow (both include the trailing
	 * NUL).  ev_name start at &ev_strings[ev_grouplen+1]
	 */
	char		ev_strings[];
};

#define	KERN_EVCNT_COUNT_ANY		0
#define	KERN_EVCNT_COUNT_NONZERO	1


/*
 * kern.hashstat returns an array of these structures, which are designed
 * to be immune to 32/64 bit emulation issues.
 *
 * Hash users can register a filler function to fill the hashstat_sysctl
 * which can then be exposed via vmstat(1).
 *
 * See comments for hashstat_sysctl() in kern/subr_hash.c for details
 * on sysctl(3) usage.
 */
struct hashstat_sysctl {
	char		hash_name[SYSCTL_NAMELEN];
	char		hash_desc[SYSCTL_NAMELEN];
	uint64_t	hash_size;
	uint64_t	hash_used;
	uint64_t	hash_items;
	uint64_t	hash_maxchain;
};
typedef int	(*hashstat_func_t)(struct hashstat_sysctl *, bool);
void		hashstat_register(const char *, hashstat_func_t);

/*
 * CTL_VM identifiers in <uvm/uvm_param.h>
 */

/*
 * The vm.proc.map sysctl allows a process to dump the VM layout of
 * another process as a series of entries.
 */
#define	KVME_TYPE_NONE		0
#define	KVME_TYPE_OBJECT	1
#define	KVME_TYPE_VNODE		2
#define	KVME_TYPE_KERN		3
#define	KVME_TYPE_DEVICE	4
#define	KVME_TYPE_ANON		5
#define	KVME_TYPE_SUBMAP	6
#define	KVME_TYPE_UNKNOWN	255

#define	KVME_PROT_READ		0x00000001
#define	KVME_PROT_WRITE		0x00000002
#define	KVME_PROT_EXEC		0x00000004

#define	KVME_FLAG_COW		0x00000001
#define	KVME_FLAG_NEEDS_COPY	0x00000002
#define	KVME_FLAG_NOCOREDUMP	0x00000004
#define	KVME_FLAG_PAGEABLE	0x00000008
#define	KVME_FLAG_GROWS_UP	0x00000010
#define	KVME_FLAG_GROWS_DOWN	0x00000020

struct kinfo_vmentry {
	uint64_t kve_start;			/* Starting address. */
	uint64_t kve_end;			/* Finishing address. */
	uint64_t kve_offset;			/* Mapping offset in object */

	uint32_t kve_type;			/* Type of map entry. */
	uint32_t kve_flags;			/* Flags on map entry. */

	uint32_t kve_count;			/* Number of pages/entries */
	uint32_t kve_wired_count;		/* Number of wired pages */

	uint32_t kve_advice;			/* Advice */
	uint32_t kve_attributes;		/* Map attribute */

	uint32_t kve_protection;		/* Protection bitmask. */
	uint32_t kve_max_protection;		/* Max protection bitmask */

	uint32_t kve_ref_count;			/* VM obj ref count. */
	uint32_t kve_inheritance;		/* Inheritance */

	uint64_t kve_vn_fileid;			/* inode number if vnode */
	uint64_t kve_vn_size;			/* File size. */
	uint64_t kve_vn_fsid;			/* dev_t of vnode location */
	uint64_t kve_vn_rdev;			/* Device id if device. */

	uint32_t kve_vn_type;			/* Vnode type. */
	uint32_t kve_vn_mode;			/* File mode. */

	char	 kve_path[PATH_MAX];		/* Path to VM obj, if any. */
};

/*
 * CTL_HW identifiers
 */
#define	HW_MACHINE	 1		/* string: machine class */
#define	HW_MODEL	 2		/* string: specific machine model */
#define	HW_NCPU		 3		/* int: number of cpus */
#define	HW_BYTEORDER	 4		/* int: machine byte order */
#define	HW_PHYSMEM	 5		/* int: total memory (bytes) */
#define	HW_USERMEM	 6		/* int: non-kernel memory (bytes) */
#define	HW_PAGESIZE	 7		/* int: software page size */
#define	HW_DISKNAMES	 8		/* string: disk drive names */
#define	HW_IOSTATS	 9		/* struct: iostats[] */
#define	HW_MACHINE_ARCH	10		/* string: machine architecture */
#define	HW_ALIGNBYTES	11		/* int: ALIGNBYTES for the kernel */
#define	HW_CNMAGIC	12		/* string: console magic sequence(s) */
#define	HW_PHYSMEM64	13		/* quad: total memory (bytes) */
#define	HW_USERMEM64	14		/* quad: non-kernel memory (bytes) */
#define	HW_IOSTATNAMES	15		/* string: iostat names */
#define	HW_NCPUONLINE	16		/* number CPUs online */

/*
 * CTL_USER definitions
 */
#define	USER_CS_PATH		 1	/* string: _CS_PATH */
#define	USER_BC_BASE_MAX	 2	/* int: BC_BASE_MAX */
#define	USER_BC_DIM_MAX		 3	/* int: BC_DIM_MAX */
#define	USER_BC_SCALE_MAX	 4	/* int: BC_SCALE_MAX */
#define	USER_BC_STRING_MAX	 5	/* int: BC_STRING_MAX */
#define	USER_COLL_WEIGHTS_MAX	 6	/* int: COLL_WEIGHTS_MAX */
#define	USER_EXPR_NEST_MAX	 7	/* int: EXPR_NEST_MAX */
#define	USER_LINE_MAX		 8	/* int: LINE_MAX */
#define	USER_RE_DUP_MAX		 9	/* int: RE_DUP_MAX */
#define	USER_POSIX2_VERSION	10	/* int: POSIX2_VERSION */
#define	USER_POSIX2_C_BIND	11	/* int: POSIX2_C_BIND */
#define	USER_POSIX2_C_DEV	12	/* int: POSIX2_C_DEV */
#define	USER_POSIX2_CHAR_TERM	13	/* int: POSIX2_CHAR_TERM */
#define	USER_POSIX2_FORT_DEV	14	/* int: POSIX2_FORT_DEV */
#define	USER_POSIX2_FORT_RUN	15	/* int: POSIX2_FORT_RUN */
#define	USER_POSIX2_LOCALEDEF	16	/* int: POSIX2_LOCALEDEF */
#define	USER_POSIX2_SW_DEV	17	/* int: POSIX2_SW_DEV */
#define	USER_POSIX2_UPE		18	/* int: POSIX2_UPE */
#define	USER_STREAM_MAX		19	/* int: POSIX2_STREAM_MAX */
#define	USER_TZNAME_MAX		20	/* int: _POSIX_TZNAME_MAX */
#define	USER_ATEXIT_MAX		21	/* int: {ATEXIT_MAX} */

/*
 * CTL_DDB definitions
 */
#define	DDBCTL_RADIX		1	/* int: Input and output radix */
#define	DDBCTL_MAXOFF		2	/* int: max symbol offset */
#define	DDBCTL_MAXWIDTH		3	/* int: width of the display line */
#define	DDBCTL_LINES		4	/* int: number of display lines */
#define	DDBCTL_TABSTOPS		5	/* int: tab width */
#define	DDBCTL_ONPANIC		6	/* int: DDB on panic if non-zero */
#define	DDBCTL_FROMCONSOLE	7	/* int: DDB via console if non-zero */

/*
 * CTL_DEBUG definitions
 *
 * Second level identifier specifies which debug variable.
 * Third level identifier specifies which structure component.
 */
#define	CTL_DEBUG_NAME		0	/* string: variable name */
#define	CTL_DEBUG_VALUE		1	/* int: variable value */

/*
 * CTL_PROC subtype. Either a PID, or a magic value for the current proc.
 */

#define	PROC_CURPROC	(~((u_int)1 << 31))

/*
 * CTL_PROC tree: either corename (string), a limit
 * (rlimit.<type>.{hard,soft}, int), a process stop
 * condition, or paxflags.
 */
#define	PROC_PID_CORENAME	1
#define	PROC_PID_LIMIT		2
#define	PROC_PID_STOPFORK	3
#define	PROC_PID_STOPEXEC	4
#define	PROC_PID_STOPEXIT	5
#define	PROC_PID_PAXFLAGS	6

/* Limit types from <sys/resources.h> */
#define	PROC_PID_LIMIT_CPU	(RLIMIT_CPU+1)
#define	PROC_PID_LIMIT_FSIZE	(RLIMIT_FSIZE+1)
#define	PROC_PID_LIMIT_DATA	(RLIMIT_DATA+1)
#define	PROC_PID_LIMIT_STACK	(RLIMIT_STACK+1)
#define	PROC_PID_LIMIT_CORE	(RLIMIT_CORE+1)
#define	PROC_PID_LIMIT_RSS	(RLIMIT_RSS+1)
#define	PROC_PID_LIMIT_MEMLOCK	(RLIMIT_MEMLOCK+1)
#define PROC_PID_LIMIT_NPROC	(RLIMIT_NPROC+1)
#define	PROC_PID_LIMIT_NOFILE	(RLIMIT_NOFILE+1)
#define	PROC_PID_LIMIT_SBSIZE	(RLIMIT_SBSIZE+1)
#define	PROC_PID_LIMIT_AS	(RLIMIT_AS+1)
#define	PROC_PID_LIMIT_NTHR	(RLIMIT_NTHR+1)

/* for each type, either hard or soft value */
#define	PROC_PID_LIMIT_TYPE_SOFT	1
#define	PROC_PID_LIMIT_TYPE_HARD	2

/*
 * Export PAX flag definitions to userland.
 *
 * XXX These are duplicated from sys/pax.h but that header is not
 * XXX installed.
 */
#define	CTL_PROC_PAXFLAGS_ASLR		0x01
#define	CTL_PROC_PAXFLAGS_MPROTECT	0x02
#define	CTL_PROC_PAXFLAGS_GUARD		0x04

/*
 * CTL_EMUL definitions
 *
 * Second level identifier specifies which emulation variable.
 * Subsequent levels are specified in the emulations themselves.
 */
#define	EMUL_LINUX	1
#define	EMUL_LINUX32	5

#ifdef _KERNEL

#if defined(_KERNEL_OPT)
#include "opt_sysctl.h"
#endif

/* Root node of the kernel sysctl tree */
extern struct sysctlnode sysctl_root;

/*
 * A log of nodes created by a setup function or set of setup
 * functions so that they can be torn down in one "transaction"
 * when no longer needed.
 *
 * Users of the log merely pass a pointer to a pointer, and the sysctl
 * infrastructure takes care of the rest.
 */
struct sysctllog;

/*
 * CTL_DEBUG variables.
 *
 * These are declared as separate variables so that they can be
 * individually initialized at the location of their associated
 * variable. The loader prevents multiple use by issuing errors
 * if a variable is initialized in more than one place. They are
 * aggregated into an array in debug_sysctl(), so that it can
 * conveniently locate them when queried. If more debugging
 * variables are added, they must also be declared here and also
 * entered into the array.
 *
 * Note that the debug subtree is largely obsolescent in terms of
 * functionality now that we have dynamic sysctl, but the
 * infrastructure is retained for backwards compatibility.
 */
struct ctldebug {
	const char *debugname;	/* name of debugging variable */
	int	*debugvar;	/* pointer to debugging variable */
};
#ifdef	DEBUG
extern struct ctldebug debug0, debug1, debug2, debug3, debug4;
extern struct ctldebug debug5, debug6, debug7, debug8, debug9;
extern struct ctldebug debug10, debug11, debug12, debug13, debug14;
extern struct ctldebug debug15, debug16, debug17, debug18, debug19;
#endif	/* DEBUG */

#define SYSCTLFN_PROTO const int *, u_int, void *, \
	size_t *, const void *, size_t, \
	const int *, struct lwp *, const struct sysctlnode *
#define SYSCTLFN_ARGS const int *name, u_int namelen, \
	void *oldp, size_t *oldlenp, \
	const void *newp, size_t newlen, \
	const int *oname, struct lwp *l, \
	const struct sysctlnode *rnode
#define SYSCTLFN_CALL(node) name, namelen, oldp, \
	oldlenp, newp, newlen, \
	oname, l, node

#ifdef RUMP_USE_CTOR
#include <sys/kernel.h>

struct sysctl_setup_chain {
	void (*ssc_func)(struct sysctllog **);
	LIST_ENTRY(sysctl_setup_chain) ssc_entries;
};
LIST_HEAD(sysctl_boot_chain, sysctl_setup_chain);
#define _SYSCTL_REGISTER(name)						\
static struct sysctl_setup_chain __CONCAT(ssc,name) = {			\
	.ssc_func = name,						\
};									\
static void sysctlctor_##name(void) __attribute__((constructor));	\
static void sysctlctor_##name(void)					\
{									\
	struct sysctl_setup_chain *ssc = &__CONCAT(ssc,name);		\
	extern struct sysctl_boot_chain sysctl_boot_chain;		\
	if (cold) {							\
		LIST_INSERT_HEAD(&sysctl_boot_chain, ssc, ssc_entries);	\
	}								\
}									\
static void sysctldtor_##name(void) __attribute__((destructor));	\
static void sysctldtor_##name(void)					\
{									\
	struct sysctl_setup_chain *ssc = &__CONCAT(ssc,name);		\
	if (cold) {							\
		LIST_REMOVE(ssc, ssc_entries);				\
	}								\
}

#else /* RUMP_USE_CTOR */

#define _SYSCTL_REGISTER(name) __link_set_add_text(sysctl_funcs, name);

#endif /* RUMP_USE_CTOR */

#ifdef _MODULE

#define SYSCTL_SETUP_PROTO(name)				\
	void name(struct sysctllog **)
#ifdef SYSCTL_DEBUG_SETUP
#define SYSCTL_SETUP(name, desc)				\
	SYSCTL_SETUP_PROTO(name);				\
	static void __CONCAT(___,name)(struct sysctllog **);	\
	void name(struct sysctllog **clog) {			\
		printf("%s\n", desc);				\
		__CONCAT(___,name)(clog); }			\
	_SYSCTL_REGISTER(name);					\
	static void __CONCAT(___,name)(struct sysctllog **clog)
#else  /* !SYSCTL_DEBUG_SETUP */
#define SYSCTL_SETUP(name, desc)				\
	SYSCTL_SETUP_PROTO(name);				\
	_SYSCTL_REGISTER(name);					\
	void name(struct sysctllog **clog)
#endif /* !SYSCTL_DEBUG_SETUP */

#else /* !_MODULE */

#define SYSCTL_SETUP_PROTO(name)
#ifdef SYSCTL_DEBUG_SETUP
#define SYSCTL_SETUP(name, desc)				\
	static void __CONCAT(___,name)(struct sysctllog **);	\
	static void name(struct sysctllog **clog) {		\
		printf("%s\n", desc);				\
		__CONCAT(___,name)(clog); }			\
	_SYSCTL_REGISTER(name);					\
	static void __CONCAT(___,name)(struct sysctllog **clog)
#else  /* !SYSCTL_DEBUG_SETUP */
#define SYSCTL_SETUP(name, desc)				\
	static void name(struct sysctllog **);			\
	_SYSCTL_REGISTER(name);					\
	static void name(struct sysctllog **clog)
#endif /* !SYSCTL_DEBUG_SETUP */

#endif /* !_MODULE */

/*
 * Internal sysctl function calling convention:
 *
 *	(*sysctlfn)(name, namelen, oldval, oldlenp, newval, newlen,
 *		    origname, lwp, node);
 *
 * The name parameter points at the next component of the name to be
 * interpreted.  The namelen parameter is the number of integers in
 * the name.  The origname parameter points to the start of the name
 * being parsed.  The node parameter points to the node on which the
 * current operation is to be performed.
 */
typedef int (*sysctlfn)(SYSCTLFN_PROTO);

/*
 * used in more than just sysctl
 */
void	fill_eproc(struct proc *, struct eproc *, bool, bool);
void	fill_kproc2(struct proc *, struct kinfo_proc2 *, bool, bool);

/*
 * subsystem setup
 */
void	sysctl_init(void);
void	sysctl_basenode_init(void);
void	sysctl_finalize(void);

/*
 * typical syscall call order
 */
void	sysctl_lock(bool);
int	sysctl_dispatch(SYSCTLFN_PROTO);
void	sysctl_unlock(void);
void	sysctl_relock(void);

/*
 * tree navigation primitives (must obtain lock before using these)
 */
int	sysctl_locate(struct lwp *, const int *, u_int,
		      const struct sysctlnode **, int *);
int	sysctl_query(SYSCTLFN_PROTO);
int	sysctl_create(SYSCTLFN_PROTO);
int	sysctl_destroy(SYSCTLFN_PROTO);
int	sysctl_lookup(SYSCTLFN_PROTO);
int	sysctl_describe(SYSCTLFN_PROTO);

/*
 * simple variadic interface for adding/removing nodes
 */
int	sysctl_createv(struct sysctllog **, int,
		       const struct sysctlnode **, const struct sysctlnode **,
		       int, int, const char *, const char *,
		       sysctlfn, u_quad_t, void *, size_t, ...);
int	sysctl_destroyv(struct sysctlnode *, ...);

#define VERIFY_FN(ctl_type, c_type) \
__always_inline static __inline void * \
__sysctl_verify_##ctl_type##_arg(c_type *arg) \
{ \
    return arg; \
}

VERIFY_FN(CTLTYPE_NODE, struct sysctlnode);
VERIFY_FN(CTLTYPE_INT, int);
VERIFY_FN(CTLTYPE_STRING, char);
VERIFY_FN(CTLTYPE_QUAD, int64_t);
VERIFY_FN(CTLTYPE_STRUCT, void);
VERIFY_FN(CTLTYPE_BOOL, bool);
VERIFY_FN(CTLTYPE_LONG, long);
#undef VERIFY_FN

#define sysctl_createv(lg, cfl, rn, cn, fl, type, nm, desc, fn, qv, newp, ...) \
    sysctl_createv(lg, cfl, rn, cn, fl, type, nm, desc, fn, qv, \
	    __sysctl_verify_##type##_arg(newp), __VA_ARGS__)

/*
 * miscellany
 */
void	sysctl_dump(const struct sysctlnode *);
void	sysctl_free(struct sysctlnode *);
void	sysctl_teardown(struct sysctllog **);
void	sysctl_log_print(const struct sysctllog *);

#ifdef SYSCTL_INCLUDE_DESCR
#define SYSCTL_DESCR(s) s
#else /* SYSCTL_INCLUDE_DESCR */
#define SYSCTL_DESCR(s) NULL
#endif /* SYSCTL_INCLUDE_DESCR */

/*
 * simple interface similar to old interface for in-kernel consumption
 */
int	old_sysctl(int *, u_int, void *, size_t *, void *, size_t, struct lwp *);

/*
 * these helpers are in other files (XXX so should the nodes be) or
 * are used by more than one node
 */
int	sysctl_hw_tapenames(SYSCTLFN_PROTO);
int	sysctl_hw_tapestats(SYSCTLFN_PROTO);
int	sysctl_kern_vnode(SYSCTLFN_PROTO);
int	sysctl_net_inet_ip_ports(SYSCTLFN_PROTO);
int	sysctl_consdev(SYSCTLFN_PROTO);
int	sysctl_root_device(SYSCTLFN_PROTO);
int	sysctl_vfs_generic_fstypes(SYSCTLFN_PROTO);

/*
 * primitive helper stubs
 */
int	sysctl_needfunc(SYSCTLFN_PROTO);
int	sysctl_notavail(SYSCTLFN_PROTO);
int	sysctl_null(SYSCTLFN_PROTO);

int	sysctl_copyin(struct lwp *, const void *, void *, size_t);
int	sysctl_copyout(struct lwp *, const void *, void *, size_t);
int	sysctl_copyinstr(struct lwp *, const void *, void *, size_t, size_t *);

u_int	sysctl_map_flags(const u_int *, u_int);

MALLOC_DECLARE(M_SYSCTLNODE);
MALLOC_DECLARE(M_SYSCTLDATA);

extern const u_int sysctl_lwpflagmap[];

#else	/* !_KERNEL */
#include <sys/cdefs.h>

typedef void *sysctlfn;

__BEGIN_DECLS
int	sysctl(const int *, u_int, void *, size_t *, const void *, size_t);
int	sysctlbyname(const char *, void *, size_t *, const void *, size_t);
int	sysctlgetmibinfo(const char *, int *, u_int *,
			 char *, size_t *, struct sysctlnode **, int);
int	sysctlnametomib(const char *, int *, size_t *);
int	proc_compare(const struct kinfo_proc2 *, const struct kinfo_lwp *,
    const struct kinfo_proc2 *, const struct kinfo_lwp *);
void	*asysctl(const int *, size_t, size_t *);
void	*asysctlbyname(const char *, size_t *);
__END_DECLS

#endif	/* !_KERNEL */

#ifdef __COMPAT_SYSCTL
/*
 * old node definitions go here
 */
#endif /* __COMPAT_SYSCTL */

/*
 * padding makes alignment magically "work" for 32/64 compatibility at
 * the expense of making things bigger on 32 bit platforms.
 */
#if defined(_LP64) || (BYTE_ORDER == LITTLE_ENDIAN)
#define __sysc_pad(type) union { uint64_t __sysc_upad; \
	struct { type __sysc_sdatum; } __sysc_ustr; }
#else
#define __sysc_pad(type) union { uint64_t __sysc_upad; \
	struct { uint32_t __sysc_spad; type __sysc_sdatum; } __sysc_ustr; }
#endif
#define __sysc_unpad(x) x.__sysc_ustr.__sysc_sdatum

/*
 * The following is for gcc2, which doesn't handle __sysc_unpad().
 * The code gets a little less ugly this way.
 */
#define sysc_init_field(field, value) 	\
	.field = { .__sysc_ustr = { .__sysc_sdatum = (value), }, }

struct sysctlnode {
	uint32_t sysctl_flags;		/* flags and type */
	int32_t sysctl_num;		/* mib number */
	char sysctl_name[SYSCTL_NAMELEN]; /* node name */
	uint32_t sysctl_ver;		/* node's version vs. rest of tree */
	uint32_t __rsvd;
	union {
		struct {
			uint32_t suc_csize;	/* size of child node array */
			uint32_t suc_clen;	/* number of valid children */
			__sysc_pad(struct sysctlnode*) _suc_child; /* array of child nodes */
		} scu_child;
		struct {
			__sysc_pad(void*) _sud_data; /* pointer to external data */
			__sysc_pad(size_t) _sud_offset; /* offset to data */
		} scu_data;
		int32_t scu_alias;		/* node this node refers to */
		int32_t scu_idata;		/* immediate "int" data */
		u_quad_t scu_qdata;		/* immediate "u_quad_t" data */
		bool scu_bdata;			/* immediate bool data */
	} sysctl_un;
	__sysc_pad(size_t) _sysctl_size;	/* size of instrumented data */
	__sysc_pad(sysctlfn) _sysctl_func;	/* access helper function */
	__sysc_pad(struct sysctlnode*) _sysctl_parent; /* parent of this node */
	__sysc_pad(const char *) _sysctl_desc;	/* description of node */
};

/*
 * padded data
 */
#define suc_child	__sysc_unpad(_suc_child)
#define sud_data	__sysc_unpad(_sud_data)
#define sud_offset	__sysc_unpad(_sud_offset)
#define sysctl_size	__sysc_unpad(_sysctl_size)
#define sysctl_func	__sysc_unpad(_sysctl_func)
#define sysctl_parent	__sysc_unpad(_sysctl_parent)
#define sysctl_desc	__sysc_unpad(_sysctl_desc)

/*
 * nested data (may also be padded)
 */
#define sysctl_csize	sysctl_un.scu_child.suc_csize
#define sysctl_clen	sysctl_un.scu_child.suc_clen
#define sysctl_child	sysctl_un.scu_child.suc_child
#define sysctl_data	sysctl_un.scu_data.sud_data
#define sysctl_offset	sysctl_un.scu_data.sud_offset
#define sysctl_alias	sysctl_un.scu_alias
#define sysctl_idata	sysctl_un.scu_idata
#define sysctl_qdata	sysctl_un.scu_qdata
#define sysctl_bdata	sysctl_un.scu_bdata

/*
 * when requesting a description of a node (a set of nodes, actually),
 * you get back an "array" of these, where the actual length of the
 * descr_str is noted in descr_len (which includes the trailing nul
 * byte), rounded up to the nearest four (sizeof(int32_t) actually).
 *
 * NEXT_DESCR() will take a pointer to a description and advance it to
 * the next description.
 */
struct sysctldesc {
	int32_t		descr_num;	/* mib number of node */
	uint32_t	descr_ver;	/* version of node */
	uint32_t	descr_len;	/* length of description string */
	char		descr_str[1];	/* not really 1...see above */
};

#define __sysc_desc_roundup(x) ((((x) - 1) | (sizeof(int32_t) - 1)) + 1)
#define __sysc_desc_len(l) (offsetof(struct sysctldesc, descr_str) +\
		__sysc_desc_roundup(l))
#define __sysc_desc_adv(d, l) \
	(/*XXXUNCONST ptr cast*/(struct sysctldesc *) \
	__UNCONST(((const char*)(d)) + __sysc_desc_len(l)))
#define NEXT_DESCR(d) __sysc_desc_adv((d), (d)->descr_len)

static __inline const struct sysctlnode *
sysctl_rootof(const struct sysctlnode *n)
{
	while (n->sysctl_parent != NULL)
		n = n->sysctl_parent;
	return (n);
}

#endif	/* !_SYS_SYSCTL_H_ */