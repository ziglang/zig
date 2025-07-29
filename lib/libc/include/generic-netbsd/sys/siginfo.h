/*	$NetBSD: siginfo.h,v 1.34 2019/09/30 21:13:33 kamil Exp $	 */

/*-
 * Copyright (c) 2002 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Christos Zoulas.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef	_SYS_SIGINFO_H_
#define	_SYS_SIGINFO_H_

#include <machine/signal.h>
#include <sys/featuretest.h>
#ifdef _KERNEL
#include <sys/queue.h>
#endif

typedef union sigval {
	int	sival_int;
	void	*sival_ptr;
} sigval_t;

struct _ksiginfo {
	int	_signo;
	int	_code;
	int	_errno;
#ifdef _LP64
	/* In _LP64 the union starts on an 8-byte boundary. */
	int	_pad;
#endif
	union {
		struct {
			pid_t	_pid;
			uid_t	_uid;
			sigval_t	_value;
		} _rt;

		struct {
			pid_t	_pid;
			uid_t	_uid;
			int	_status;
			clock_t	_utime;
			clock_t	_stime;
		} _child;

		struct {
			void   *_addr;
			int	_trap;
			int	_trap2;
			int	_trap3;
		} _fault;

		struct {
			long	_band;
			int	_fd;
		} _poll;

		struct {
			int	_sysnum;
			int	_retval[2];
			int	_error;
			uint64_t _args[8]; /* SYS_MAXSYSARGS */
		} _syscall;

		struct {
			int	_pe_report_event;
			union {
				pid_t _pe_other_pid;
				lwpid_t _pe_lwp;
			} _option;
		} _ptrace_state;
	} _reason;
};

#ifdef _KERNEL
typedef struct ksiginfo {
	u_long			ksi_flags;	/* 4 or 8 bytes (LP64) */
	TAILQ_ENTRY(ksiginfo)	ksi_list;
	struct _ksiginfo	ksi_info;
	lwpid_t			ksi_lid;	/* 0, or directed to LWP */
} ksiginfo_t;

#define	KSI_TRAP	0x01	/* signal caused by trap */
#define	KSI_EMPTY	0x02	/* no additional information */
#define	KSI_QUEUED	0x04	/* on a sigpend_t queue */
#define	KSI_FROMPOOL	0x08	/* allocated from the ksiginfo pool */

/* Macros to initialize a ksiginfo_t. */
#define	KSI_INIT(ksi)							\
do {									\
	memset((ksi), 0, sizeof(*(ksi)));				\
} while (/*CONSTCOND*/0)

#define	KSI_INIT_EMPTY(ksi)						\
do {									\
	KSI_INIT((ksi));						\
	(ksi)->ksi_flags = KSI_EMPTY;					\
} while (/*CONSTCOND*/0)

#define	KSI_INIT_TRAP(ksi)						\
do {									\
	KSI_INIT((ksi));						\
	(ksi)->ksi_flags = KSI_TRAP;					\
} while (/*CONSTCOND*/0)

/* Copy the part of ksiginfo_t without the queue pointers */
#define	KSI_COPY(fksi, tksi)						\
do {									\
	(tksi)->ksi_info = (fksi)->ksi_info;				\
	(tksi)->ksi_flags = (fksi)->ksi_flags;				\
} while (/*CONSTCOND*/0)


/* Predicate macros to test how a ksiginfo_t was generated. */
#define	KSI_TRAP_P(ksi)		(((ksi)->ksi_flags & KSI_TRAP) != 0)
#define	KSI_EMPTY_P(ksi)	(((ksi)->ksi_flags & KSI_EMPTY) != 0)

/*
 * Old-style signal handler "code" arguments were only non-zero for
 * signals caused by traps.
 */
#define	KSI_TRAPCODE(ksi)	(KSI_TRAP_P(ksi) ? (ksi)->ksi_trap : 0)
#endif /* _KERNEL */

typedef union siginfo {
	char	si_pad[128];	/* Total size; for future expansion */
	struct _ksiginfo _info;
} siginfo_t;

/** Field access macros */
#define	si_signo	_info._signo
#define	si_code		_info._code
#define	si_errno	_info._errno

#define	si_value	_info._reason._rt._value
#define	si_pid		_info._reason._child._pid
#define	si_uid		_info._reason._child._uid
#define	si_status	_info._reason._child._status
#define	si_utime	_info._reason._child._utime
#define	si_stime	_info._reason._child._stime

#define	si_addr		_info._reason._fault._addr
#define	si_trap		_info._reason._fault._trap
#define	si_trap2	_info._reason._fault._trap2
#define	si_trap3	_info._reason._fault._trap3

#define	si_band		_info._reason._poll._band
#define	si_fd		_info._reason._poll._fd

#define	si_sysnum	_info._reason._syscall._sysnum
#define si_retval	_info._reason._syscall._retval
#define si_error	_info._reason._syscall._error
#define si_args		_info._reason._syscall._args

#define si_pe_report_event	_info._reason._ptrace_state._pe_report_event
#define si_pe_other_pid	_info._reason._ptrace_state._option._pe_other_pid
#define si_pe_lwp	_info._reason._ptrace_state._option._pe_lwp

#ifdef _KERNEL
/** Field access macros */
#define	ksi_signo	ksi_info._signo
#define	ksi_code	ksi_info._code
#define	ksi_errno	ksi_info._errno

#define	ksi_value	ksi_info._reason._rt._value
#define	ksi_pid		ksi_info._reason._child._pid
#define	ksi_uid		ksi_info._reason._child._uid
#define	ksi_status	ksi_info._reason._child._status
#define	ksi_utime	ksi_info._reason._child._utime
#define	ksi_stime	ksi_info._reason._child._stime

#define	ksi_addr	ksi_info._reason._fault._addr
#define	ksi_trap	ksi_info._reason._fault._trap
#define	ksi_trap2	ksi_info._reason._fault._trap2
#define	ksi_trap3	ksi_info._reason._fault._trap3

#define	ksi_band	ksi_info._reason._poll._band
#define	ksi_fd		ksi_info._reason._poll._fd

#define	ksi_sysnum	ksi_info._reason._syscall._sysnum
#define ksi_retval	ksi_info._reason._syscall._retval
#define ksi_error	ksi_info._reason._syscall._error
#define ksi_args	ksi_info._reason._syscall._args

#define ksi_pe_report_event	ksi_info._reason._ptrace_state._pe_report_event
#define ksi_pe_other_pid	ksi_info._reason._ptrace_state._option._pe_other_pid
#define ksi_pe_lwp		ksi_info._reason._ptrace_state._option._pe_lwp
#endif /* _KERNEL */

/** si_code */
/* SIGILL */
#define	ILL_ILLOPC	1	/* Illegal opcode			*/
#define	ILL_ILLOPN	2	/* Illegal operand			*/
#define	ILL_ILLADR	3	/* Illegal addressing mode		*/
#define	ILL_ILLTRP	4	/* Illegal trap				*/
#define	ILL_PRVOPC	5	/* Privileged opcode			*/
#define	ILL_PRVREG	6	/* Privileged register			*/
#define	ILL_COPROC	7	/* Coprocessor error			*/
#define	ILL_BADSTK	8	/* Internal stack error			*/

/* SIGFPE */
#define	FPE_INTDIV	1	/* Integer divide by zero		*/
#define	FPE_INTOVF	2	/* Integer overflow			*/
#define	FPE_FLTDIV	3	/* Floating point divide by zero	*/
#define	FPE_FLTOVF	4	/* Floating point overflow		*/
#define	FPE_FLTUND	5	/* Floating point underflow		*/
#define	FPE_FLTRES	6	/* Floating point inexact result	*/
#define	FPE_FLTINV	7	/* Invalid Floating point operation	*/
#define	FPE_FLTSUB	8	/* Subscript out of range		*/

/* SIGSEGV */
#define	SEGV_MAPERR	1	/* Address not mapped to object		*/
#define	SEGV_ACCERR	2	/* Invalid permissions for mapped object*/

/* SIGBUS */
#define	BUS_ADRALN	1	/* Invalid address alignment		*/
#define	BUS_ADRERR	2	/* Non-existent physical address	*/
#define	BUS_OBJERR	3	/* Object specific hardware error	*/

/* SIGTRAP */
#define	TRAP_BRKPT	1	/* Process breakpoint			*/
#define	TRAP_TRACE	2	/* Process trace trap			*/
#define	TRAP_EXEC	3	/* Process exec trap			*/
#define	TRAP_CHLD	4	/* Process child trap			*/
#define	TRAP_LWP	5	/* Process lwp trap			*/
#define	TRAP_DBREG	6	/* Process hardware debug register trap	*/
#define	TRAP_SCE	7	/* Process syscall entry trap		*/
#define	TRAP_SCX	8	/* Process syscall exit trap		*/

/* SIGCHLD */
#define	CLD_EXITED	1	/* Child has exited			*/
#define	CLD_KILLED	2	/* Child has terminated abnormally but	*/
				/* did not create a core file		*/
#define	CLD_DUMPED	3	/* Child has terminated abnormally and	*/
				/* created a core file			*/
#define	CLD_TRAPPED	4	/* Traced child has trapped		*/
#define	CLD_STOPPED	5	/* Child has stopped			*/
#define	CLD_CONTINUED	6	/* Stopped child has continued		*/

/* SIGIO */
#define	POLL_IN		1	/* Data input available			*/
#define	POLL_OUT	2	/* Output buffers available		*/
#define	POLL_MSG	3	/* Input message available		*/
#define	POLL_ERR	4	/* I/O Error				*/
#define	POLL_PRI	5	/* High priority input available	*/
#define	POLL_HUP	6	/* Device disconnected			*/


/** si_code */
#define	SI_USER		0	/* Sent by kill(2)			*/
#define	SI_QUEUE	-1	/* Sent by the sigqueue(2)		*/
#define	SI_TIMER	-2	/* Generated by expiration of a timer	*/
				/* set by timer_settime(2)		*/
#define	SI_ASYNCIO	-3	/* Generated by completion of an	*/
				/* asynchronous I/O signal		*/
#define	SI_MESGQ	-4	/* Generated by arrival of a message on	*/
				/* an empty message queue		*/
#if defined(_KERNEL) || defined(_NETBSD_SOURCE)
#define	SI_LWP		-5	/* Generated by _lwp_kill(2)		*/
#define	SI_NOINFO	32767	/* No signal specific info available	*/
#endif

#endif /* !_SYS_SIGINFO_H_ */