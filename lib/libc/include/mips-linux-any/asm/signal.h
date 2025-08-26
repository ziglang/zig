/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/*
 * This file is subject to the terms and conditions of the GNU General Public
 * License.  See the file "COPYING" in the main directory of this archive
 * for more details.
 *
 * Copyright (C) 1995, 96, 97, 98, 99, 2003 by Ralf Baechle
 * Copyright (C) 1999 Silicon Graphics, Inc.
 */
#ifndef _ASM_SIGNAL_H
#define _ASM_SIGNAL_H

#include <linux/types.h>

#define _NSIG		128
#define _NSIG_BPW	(sizeof(unsigned long) * 8)
#define _NSIG_WORDS	(_NSIG / _NSIG_BPW)

typedef struct {
	unsigned long sig[_NSIG_WORDS];
} sigset_t;

typedef unsigned long old_sigset_t;		/* at least 32 bits */

#define SIGHUP		 1	/* Hangup (POSIX).  */
#define SIGINT		 2	/* Interrupt (ANSI).  */
#define SIGQUIT		 3	/* Quit (POSIX).  */
#define SIGILL		 4	/* Illegal instruction (ANSI).	*/
#define SIGTRAP		 5	/* Trace trap (POSIX).	*/
#define SIGIOT		 6	/* IOT trap (4.2 BSD).	*/
#define SIGABRT		 SIGIOT /* Abort (ANSI).  */
#define SIGEMT		 7
#define SIGFPE		 8	/* Floating-point exception (ANSI).  */
#define SIGKILL		 9	/* Kill, unblockable (POSIX).  */
#define SIGBUS		10	/* BUS error (4.2 BSD).	 */
#define SIGSEGV		11	/* Segmentation violation (ANSI).  */
#define SIGSYS		12
#define SIGPIPE		13	/* Broken pipe (POSIX).	 */
#define SIGALRM		14	/* Alarm clock (POSIX).	 */
#define SIGTERM		15	/* Termination (ANSI).	*/
#define SIGUSR1		16	/* User-defined signal 1 (POSIX).  */
#define SIGUSR2		17	/* User-defined signal 2 (POSIX).  */
#define SIGCHLD		18	/* Child status has changed (POSIX).  */
#define SIGCLD		SIGCHLD /* Same as SIGCHLD (System V).	*/
#define SIGPWR		19	/* Power failure restart (System V).  */
#define SIGWINCH	20	/* Window size change (4.3 BSD, Sun).  */
#define SIGURG		21	/* Urgent condition on socket (4.2 BSD).  */
#define SIGIO		22	/* I/O now possible (4.2 BSD).	*/
#define SIGPOLL		SIGIO	/* Pollable event occurred (System V).	*/
#define SIGSTOP		23	/* Stop, unblockable (POSIX).  */
#define SIGTSTP		24	/* Keyboard stop (POSIX).  */
#define SIGCONT		25	/* Continue (POSIX).  */
#define SIGTTIN		26	/* Background read from tty (POSIX).  */
#define SIGTTOU		27	/* Background write to tty (POSIX).  */
#define SIGVTALRM	28	/* Virtual alarm clock (4.2 BSD).  */
#define SIGPROF		29	/* Profiling alarm clock (4.2 BSD).  */
#define SIGXCPU		30	/* CPU limit exceeded (4.2 BSD).  */
#define SIGXFSZ		31	/* File size limit exceeded (4.2 BSD).	*/

/* These should not be considered constants from userland.  */
#define SIGRTMIN	32
#define SIGRTMAX	_NSIG

/*
 * SA_RESTORER used to be defined as 0x04000000 but only the O32 ABI ever
 * supported its use and no libc was using it, so the entire sa-restorer
 * functionality was removed with lmo commit 39bffc12c3580ab for 2.5.48
 * retaining only the SA_RESTORER definition as a reminder to avoid
 * accidental reuse of the mask bit.
 */
#define SA_ONSTACK	0x08000000
#define SA_RESETHAND	0x80000000
#define SA_RESTART	0x10000000
#define SA_SIGINFO	0x00000008
#define SA_NODEFER	0x40000000
#define SA_NOCLDWAIT	0x00010000
#define SA_NOCLDSTOP	0x00000001

#define SA_NOMASK	SA_NODEFER
#define SA_ONESHOT	SA_RESETHAND

#define MINSIGSTKSZ    2048
#define SIGSTKSZ       8192


#define SIG_BLOCK	1	/* for blocking signals */
#define SIG_UNBLOCK	2	/* for unblocking signals */
#define SIG_SETMASK	3	/* for setting the signal mask */

#include <asm-generic/signal-defs.h>

struct sigaction {
	unsigned int	sa_flags;
	__sighandler_t	sa_handler;
	sigset_t	sa_mask;
};

/* IRIX compatible stack_t  */
typedef struct sigaltstack {
	void *ss_sp;
	__kernel_size_t ss_size;
	int ss_flags;
} stack_t;


#endif /* _ASM_SIGNAL_H */