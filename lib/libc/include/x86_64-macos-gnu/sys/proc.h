/*
 * Copyright (c) 2000-2018 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/* Copyright (c) 1995, 1997 Apple Computer, Inc. All Rights Reserved */
/*-
 * Copyright (c) 1986, 1989, 1991, 1993
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
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)proc.h	8.15 (Berkeley) 5/19/95
 */

#ifndef _SYS_PROC_H_
#define _SYS_PROC_H_

#include <sys/appleapiopts.h>
#include <sys/cdefs.h>
#include <sys/select.h>                 /* For struct selinfo. */
#include <sys/queue.h>
#include <sys/lock.h>
#include <sys/param.h>
#include <sys/event.h>
#include <sys/time.h>
#include <mach/boolean.h>



struct session;
struct pgrp;
struct proc;

/* Exported fields for kern sysctls */
struct extern_proc {
	union {
		struct {
			struct  proc *__p_forw; /* Doubly-linked run/sleep queue. */
			struct  proc *__p_back;
		} p_st1;
		struct timeval __p_starttime;   /* process start time */
	} p_un;
#define p_forw p_un.p_st1.__p_forw
#define p_back p_un.p_st1.__p_back
#define p_starttime p_un.__p_starttime
	struct  vmspace *p_vmspace;     /* Address space. */
	struct  sigacts *p_sigacts;     /* Signal actions, state (PROC ONLY). */
	int     p_flag;                 /* P_* flags. */
	char    p_stat;                 /* S* process status. */
	pid_t   p_pid;                  /* Process identifier. */
	pid_t   p_oppid;         /* Save parent pid during ptrace. XXX */
	int     p_dupfd;         /* Sideways return value from fdopen. XXX */
	/* Mach related  */
	caddr_t user_stack;     /* where user stack was allocated */
	void    *exit_thread;   /* XXX Which thread is exiting? */
	int             p_debugger;             /* allow to debug */
	boolean_t       sigwait;        /* indication to suspend */
	/* scheduling */
	u_int   p_estcpu;        /* Time averaged value of p_cpticks. */
	int     p_cpticks;       /* Ticks of cpu time. */
	fixpt_t p_pctcpu;        /* %cpu for this process during p_swtime */
	void    *p_wchan;        /* Sleep address. */
	char    *p_wmesg;        /* Reason for sleep. */
	u_int   p_swtime;        /* Time swapped in or out. */
	u_int   p_slptime;       /* Time since last blocked. */
	struct  itimerval p_realtimer;  /* Alarm timer. */
	struct  timeval p_rtime;        /* Real time. */
	u_quad_t p_uticks;              /* Statclock hits in user mode. */
	u_quad_t p_sticks;              /* Statclock hits in system mode. */
	u_quad_t p_iticks;              /* Statclock hits processing intr. */
	int     p_traceflag;            /* Kernel trace points. */
	struct  vnode *p_tracep;        /* Trace to vnode. */
	int     p_siglist;              /* DEPRECATED. */
	struct  vnode *p_textvp;        /* Vnode of executable. */
	int     p_holdcnt;              /* If non-zero, don't swap. */
	sigset_t p_sigmask;     /* DEPRECATED. */
	sigset_t p_sigignore;   /* Signals being ignored. */
	sigset_t p_sigcatch;    /* Signals being caught by user. */
	u_char  p_priority;     /* Process priority. */
	u_char  p_usrpri;       /* User-priority based on p_cpu and p_nice. */
	char    p_nice;         /* Process "nice" value. */
	char    p_comm[MAXCOMLEN + 1];
	struct  pgrp *p_pgrp;   /* Pointer to process group. */
	struct  user *p_addr;   /* Kernel virtual addr of u-area (PROC ONLY). */
	u_short p_xstat;        /* Exit status for wait; also stop signal. */
	u_short p_acflag;       /* Accounting flags. */
	struct  rusage *p_ru;   /* Exit information. XXX */
};


/* Status values. */
#define SIDL    1               /* Process being created by fork. */
#define SRUN    2               /* Currently runnable. */
#define SSLEEP  3               /* Sleeping on an address. */
#define SSTOP   4               /* Process debugging or suspension. */
#define SZOMB   5               /* Awaiting collection by parent. */

/* These flags are kept in extern_proc.p_flag. */
#define P_ADVLOCK       0x00000001      /* Process may hold POSIX adv. lock */
#define P_CONTROLT      0x00000002      /* Has a controlling terminal */
#define P_LP64          0x00000004      /* Process is LP64 */
#define P_NOCLDSTOP     0x00000008      /* No SIGCHLD when children stop */

#define P_PPWAIT        0x00000010      /* Parent waiting for chld exec/exit */
#define P_PROFIL        0x00000020      /* Has started profiling */
#define P_SELECT        0x00000040      /* Selecting; wakeup/waiting danger */
#define P_CONTINUED     0x00000080      /* Process was stopped and continued */

#define P_SUGID         0x00000100      /* Has set privileges since last exec */
#define P_SYSTEM        0x00000200      /* Sys proc: no sigs, stats or swap */
#define P_TIMEOUT       0x00000400      /* Timing out during sleep */
#define P_TRACED        0x00000800      /* Debugged process being traced */

#define P_DISABLE_ASLR  0x00001000      /* Disable address space layout randomization */
#define P_WEXIT         0x00002000      /* Working on exiting */
#define P_EXEC          0x00004000      /* Process called exec. */

/* Should be moved to machine-dependent areas. */
#define P_OWEUPC        0x00008000      /* Owe process an addupc() call at next ast. */

#define P_AFFINITY      0x00010000      /* xxx */
#define P_TRANSLATED    0x00020000      /* xxx */
#define P_CLASSIC       P_TRANSLATED    /* xxx */

#define P_DELAYIDLESLEEP 0x00040000     /* Process is marked to delay idle sleep on disk IO */
#define P_CHECKOPENEVT  0x00080000      /* check if a vnode has the OPENEVT flag set on open */

#define P_DEPENDENCY_CAPABLE    0x00100000      /* process is ok to call vfs_markdependency() */
#define P_REBOOT        0x00200000      /* Process called reboot() */
#define P_RESV6         0x00400000      /* used to be P_TBE */
#define P_RESV7         0x00800000      /* (P_SIGEXC)signal exceptions */

#define P_THCWD         0x01000000      /* process has thread cwd  */
#define P_RESV9         0x02000000      /* (P_VFORK)process has vfork children */
#define P_ADOPTPERSONA  0x04000000      /* process adopted a persona (used to be P_NOATTACH) */
#define P_RESV11        0x08000000      /* (P_INVFORK) proc in vfork */

#define P_NOSHLIB       0x10000000      /* no shared libs are in use for proc */
                                        /* flag set on exec */
#define P_FORCEQUOTA    0x20000000      /* Force quota for root */
#define P_NOCLDWAIT     0x40000000      /* No zombies when chil procs exit */
#define P_NOREMOTEHANG  0x80000000      /* Don't hang on remote FS ops */

#define P_INMEM         0               /* Obsolete: retained for compilation */
#define P_NOSWAP        0               /* Obsolete: retained for compilation */
#define P_PHYSIO        0               /* Obsolete: retained for compilation */
#define P_FSTRACE       0               /* Obsolete: retained for compilation */
#define P_SSTEP         0               /* Obsolete: retained for compilation */

#define P_DIRTY_TRACK                           0x00000001      /* track dirty state */
#define P_DIRTY_ALLOW_IDLE_EXIT                 0x00000002      /* process can be idle-exited when clean */
#define P_DIRTY_DEFER                           0x00000004      /* defer initial opt-in to idle-exit */
#define P_DIRTY                                 0x00000008      /* process is dirty */
#define P_DIRTY_SHUTDOWN                        0x00000010      /* process is dirty during shutdown */
#define P_DIRTY_TERMINATED                      0x00000020      /* process has been marked for termination */
#define P_DIRTY_BUSY                            0x00000040      /* serialization flag */
#define P_DIRTY_MARKED                          0x00000080      /* marked dirty previously */
#define P_DIRTY_AGING_IN_PROGRESS               0x00000100      /* aging in one of the 'aging bands' */
#define P_DIRTY_LAUNCH_IN_PROGRESS              0x00000200      /* launch is in progress */
#define P_DIRTY_DEFER_ALWAYS                    0x00000400      /* defer going to idle-exit after every dirty->clean transition.
	                                                         * For legacy jetsam policy only. This is the default with the other policies.*/

#define P_DIRTY_IS_DIRTY                        (P_DIRTY | P_DIRTY_SHUTDOWN)
#define P_DIRTY_IDLE_EXIT_ENABLED               (P_DIRTY_TRACK|P_DIRTY_ALLOW_IDLE_EXIT)




#endif  /* !_SYS_PROC_H_ */
