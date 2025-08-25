/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1988, 1993
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
 *	@(#)ktrace.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _SYS_KTRACE_H_
#define _SYS_KTRACE_H_

#include <sys/param.h>
#include <sys/caprights.h>
#include <sys/signal.h>
#include <sys/socket.h>
#include <sys/_uio.h>

/*
 * operations to ktrace system call  (KTROP(op))
 */
#define KTROP_SET		0	/* set trace points */
#define KTROP_CLEAR		1	/* clear trace points */
#define KTROP_CLEARFILE		2	/* stop all tracing to file */
#define	KTROP(o)		((o)&3)	/* macro to extract operation */
/*
 * flags (ORed in with operation)
 */
#define KTRFLAG_DESCEND		4	/* perform op on all children too */

/*
 * ktrace record header
 */
struct ktr_header_v0 {
	int	ktr_len;		/* length of buf */
	short	ktr_type;		/* trace record type */
	pid_t	ktr_pid;		/* process id */
	char	ktr_comm[MAXCOMLEN + 1];/* command name */
	struct	timeval ktr_time;	/* timestamp */
	long	ktr_tid;		/* thread id */
};

struct ktr_header {
	int	ktr_len;		/* length of buf */
	short	ktr_type;		/* trace record type */
	short	ktr_version;		/* ktr_header version */
	pid_t	ktr_pid;		/* process id */
	char	ktr_comm[MAXCOMLEN + 1];/* command name */
	struct	timespec ktr_time;	/* timestamp */
	/* XXX: make ktr_tid an lwpid_t on next ABI break */
	long	ktr_tid;		/* thread id */
	int	ktr_cpu;		/* cpu id */
};

#define	KTR_VERSION0	0
#define	KTR_VERSION1	1
#define	KTR_OFFSET_V0	sizeof(struct ktr_header_v0) - \
			    sizeof(struct ktr_header)
/*
 * Test for kernel trace point (MP SAFE).
 *
 * KTRCHECK() just checks that the type is enabled and is only for
 * internal use in the ktrace subsystem.  KTRPOINT() checks against
 * ktrace recursion as well as checking that the type is enabled and
 * is the public interface.
 */
#define	KTRCHECK(td, type)	((td)->td_proc->p_traceflag & (1 << type))
#define KTRPOINT(td, type)  (__predict_false(KTRCHECK((td), (type))))
#define	KTRCHECKDRAIN(td)	(!(STAILQ_EMPTY(&(td)->td_proc->p_ktr)))
#define	KTRUSERRET(td) do {						\
	if (__predict_false(KTRCHECKDRAIN(td)))				\
		ktruserret(td);						\
} while (0)

/*
 * ktrace record types
 */

/*
 * KTR_SYSCALL - system call record
 */
#define KTR_SYSCALL	1
struct ktr_syscall {
	short	ktr_code;		/* syscall number */
	short	ktr_narg;		/* number of arguments */
	/*
	 * followed by ktr_narg register_t
	 */
	register_t	ktr_args[1];
};

/*
 * KTR_SYSRET - return from system call record
 */
#define KTR_SYSRET	2
struct ktr_sysret {
	short	ktr_code;
	short	ktr_eosys;
	int	ktr_error;
	register_t	ktr_retval;
};

/*
 * KTR_NAMEI - namei record
 */
#define KTR_NAMEI	3
	/* record contains pathname */

/*
 * KTR_GENIO - trace generic process i/o
 */
#define KTR_GENIO	4
struct ktr_genio {
	int	ktr_fd;
	enum	uio_rw ktr_rw;
	/*
	 * followed by data successfully read/written
	 */
};

/*
 * KTR_PSIG - trace processed signal
 */
#define	KTR_PSIG	5
struct ktr_psig {
	int	signo;
	sig_t	action;
	int	code;
	sigset_t mask;
};

/*
 * KTR_CSW - trace context switches
 */
#define KTR_CSW		6
struct ktr_csw_old {
	int	out;	/* 1 if switch out, 0 if switch in */
	int	user;	/* 1 if usermode (ivcsw), 0 if kernel (vcsw) */
};

struct ktr_csw {
	int	out;	/* 1 if switch out, 0 if switch in */
	int	user;	/* 1 if usermode (ivcsw), 0 if kernel (vcsw) */
	char	wmesg[8];
};

/*
 * KTR_USER - data coming from userland
 */
#define KTR_USER_MAXLEN	2048	/* maximum length of passed data */
#define KTR_USER	7

/*
 * KTR_STRUCT - misc. structs
 */
#define KTR_STRUCT	8
	/*
	 * record contains null-terminated struct name followed by
	 * struct contents
	 */
struct sockaddr;
struct stat;
struct sysentvec;

/*
 * KTR_SYSCTL - name of a sysctl MIB
 */
#define	KTR_SYSCTL	9
	/* record contains null-terminated MIB name */

/*
 * KTR_PROCCTOR - trace process creation (multiple ABI support)
 */
#define KTR_PROCCTOR	10
struct ktr_proc_ctor {
	u_int	sv_flags;	/* struct sysentvec sv_flags copy */
};

/*
 * KTR_PROCDTOR - trace process destruction (multiple ABI support)
 */
#define KTR_PROCDTOR	11

/*
 * KTR_CAPFAIL - trace capability check failures
 */
#define KTR_CAPFAIL	12
enum ktr_cap_violation {
	CAPFAIL_NOTCAPABLE,	/* insufficient capabilities in cap_check() */
	CAPFAIL_INCREASE,	/* attempt to increase rights on a capability */
	CAPFAIL_SYSCALL,	/* disallowed system call */
	CAPFAIL_SIGNAL,		/* sent signal to process other than self */
	CAPFAIL_PROTO,		/* disallowed protocol */
	CAPFAIL_SOCKADDR,	/* restricted address lookup */
	CAPFAIL_NAMEI,		/* restricted namei lookup */
	CAPFAIL_CPUSET,		/* restricted CPU set modification */
};

union ktr_cap_data {
	cap_rights_t	cap_rights[2];
#define	cap_needed	cap_rights[0]
#define	cap_held	cap_rights[1]
	int		cap_int;
	struct sockaddr	cap_sockaddr;
	char		cap_path[MAXPATHLEN];
};

struct ktr_cap_fail {
	enum ktr_cap_violation cap_type;
	short	cap_code;
	u_int	cap_svflags;
	union ktr_cap_data cap_data;
};

/*
 * KTR_FAULT - page fault record
 */
#define KTR_FAULT	13
struct ktr_fault {
	vm_offset_t vaddr;
	int type;
};

/*
 * KTR_FAULTEND - end of page fault record
 */
#define KTR_FAULTEND	14
struct ktr_faultend {
	int result;
};

/*
 * KTR_STRUCT_ARRAY - array of misc. structs
 */
#define	KTR_STRUCT_ARRAY 15
struct ktr_struct_array {
	size_t struct_size;
	/*
	 * Followed by null-terminated structure name and then payload
	 * contents.
	 */
};

/*
 * KTR_DROP - If this bit is set in ktr_type, then at least one event
 * between the previous record and this record was dropped.
 */
#define	KTR_DROP	0x8000
/*
 * KTR_VERSIONED - If this bit is set in ktr_type, then the kernel
 * exposes the new struct ktr_header (versioned), otherwise the old
 * struct ktr_header_v0 is exposed.
 */
#define	KTR_VERSIONED	0x4000
#define	KTR_TYPE	(KTR_DROP | KTR_VERSIONED)

/*
 * kernel trace points (in p_traceflag)
 */
#define KTRFAC_MASK	0x00ffffff
#define KTRFAC_SYSCALL	(1<<KTR_SYSCALL)
#define KTRFAC_SYSRET	(1<<KTR_SYSRET)
#define KTRFAC_NAMEI	(1<<KTR_NAMEI)
#define KTRFAC_GENIO	(1<<KTR_GENIO)
#define	KTRFAC_PSIG	(1<<KTR_PSIG)
#define KTRFAC_CSW	(1<<KTR_CSW)
#define KTRFAC_USER	(1<<KTR_USER)
#define KTRFAC_STRUCT	(1<<KTR_STRUCT)
#define KTRFAC_SYSCTL	(1<<KTR_SYSCTL)
#define KTRFAC_PROCCTOR	(1<<KTR_PROCCTOR)
#define KTRFAC_PROCDTOR	(1<<KTR_PROCDTOR)
#define KTRFAC_CAPFAIL	(1<<KTR_CAPFAIL)
#define KTRFAC_FAULT	(1<<KTR_FAULT)
#define KTRFAC_FAULTEND	(1<<KTR_FAULTEND)
#define	KTRFAC_STRUCT_ARRAY (1<<KTR_STRUCT_ARRAY)

/*
 * trace flags (also in p_traceflags)
 */
#define KTRFAC_ROOT	0x80000000	/* root set this trace */
#define KTRFAC_INHERIT	0x40000000	/* pass trace flags to children */
#define	KTRFAC_DROP	0x20000000	/* last event was dropped */

#ifdef	_KERNEL
struct ktr_io_params;

#ifdef	KTRACE
struct vnode *ktr_get_tracevp(struct proc *, bool);
#else
static inline struct vnode *
ktr_get_tracevp(struct proc *p, bool ref)
{

	return (NULL);
}
#endif
void	ktr_io_params_free(struct ktr_io_params *);
void	ktrnamei(const char *);
void	ktrcsw(int, int, const char *);
void	ktrpsig(int, sig_t, sigset_t *, int);
void	ktrfault(vm_offset_t, int);
void	ktrfaultend(int);
void	ktrgenio(int, enum uio_rw, struct uio *, int);
void	ktrsyscall(int, int narg, syscallarg_t args[]);
void	ktrsysctl(int *name, u_int namelen);
void	ktrsysret(int, int, register_t);
void	ktrprocctor(struct proc *);
struct ktr_io_params *ktrprocexec(struct proc *);
void	ktrprocexit(struct thread *);
void	ktrprocfork(struct proc *, struct proc *);
void	ktruserret(struct thread *);
void	ktrstruct(const char *, const void *, size_t);
void	ktrstruct_error(const char *, const void *, size_t, int);
void	ktrstructarray(const char *, enum uio_seg, const void *, int, size_t);
void	ktrcapfail(enum ktr_cap_violation, const void *);
#define ktrcaprights(s) \
	ktrstruct("caprights", (s), sizeof(cap_rights_t))
#define	ktritimerval(s) \
	ktrstruct("itimerval", (s), sizeof(struct itimerval))
#define ktrsockaddr(s) \
	ktrstruct("sockaddr", (s), ((struct sockaddr *)(s))->sa_len)
#define ktrstat(s) \
	ktrstruct("stat", (s), sizeof(struct stat))
#define ktrstat_error(s, error) \
	ktrstruct_error("stat", (s), sizeof(struct stat), error)
#define ktrcpuset(s, l) \
	ktrstruct("cpuset_t", (s), l)
#define	ktrsplice(s) \
	ktrstruct("splice", (s), sizeof(struct splice))
extern u_int ktr_geniosize;
#ifdef	KTRACE
extern int ktr_filesize_limit_signal;
#define	__ktrace_used
#else
#define	ktr_filesize_limit_signal 0
#define	__ktrace_used	__unused
#endif
#else

#include <sys/cdefs.h>

__BEGIN_DECLS
int	ktrace(const char *, int, int, pid_t);
int	utrace(const void *, size_t);
__END_DECLS

#endif

#endif