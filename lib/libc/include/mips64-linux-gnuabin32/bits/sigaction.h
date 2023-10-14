/* The proper definitions for Linux/MIPS's sigaction.
   Copyright (C) 1993-2023 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _BITS_SIGACTION_H
#define _BITS_SIGACTION_H 1

#ifndef _SIGNAL_H
# error "Never include <bits/sigaction.h> directly; use <signal.h> instead."
#endif

/* Structure describing the action to be taken when a signal arrives.  */
struct sigaction
  {
    /* Special flags.  */
    int sa_flags;

    /* Signal handler.  */
#if defined __USE_POSIX199309 || defined __USE_XOPEN_EXTENDED
    union
      {
	/* Used if SA_SIGINFO is not set.  */
	__sighandler_t sa_handler;
	/* Used if SA_SIGINFO is set.  */
	void (*sa_sigaction) (int, siginfo_t *, void *);
      }
    __sigaction_handler;
# define sa_handler    __sigaction_handler.sa_handler
# define sa_sigaction  __sigaction_handler.sa_sigaction
#else
    __sighandler_t sa_handler;
#endif
    /* Additional set of signals to be blocked.  */
    __sigset_t sa_mask;

    /* The ABI says here are two unused ints following. */
    /* Restore handler.  */
    void (*sa_restorer) (void);

#if _MIPS_SZPTR < 64
    int sa_resv[1];
#endif
  };

/* Bits in `sa_flags'.  */
/* Please note that some Linux kernels versions use different values for these
   flags which is a bug in those kernel versions.  */
#define SA_NOCLDSTOP  0x00000001 /* Don't send SIGCHLD when children stop.  */
#define SA_NOCLDWAIT  0x00010000 /* Don't create zombie on child death.  */
#define SA_SIGINFO    0x00000008 /* Invoke signal-catching function with
				    three arguments instead of one.  */
#if defined __USE_XOPEN_EXTENDED || defined __USE_MISC
# define SA_ONSTACK   0x08000000 /* Use signal stack by using `sa_restorer'. */
#endif
#if defined __USE_XOPEN_EXTENDED || defined __USE_XOPEN2K8
# define SA_RESETHAND 0x80000000 /* Reset to SIG_DFL on entry to handler.  */
# define SA_RESTART   0x10000000 /* Restart syscall on signal return.  */
# define SA_NODEFER   0x40000000 /* Don't automatically block the signal when
				    its handler is being executed.  */
#endif
#ifdef __USE_MISC
# define SA_INTERRUPT 0x20000000 /* Historical no-op.  */

/* Some aliases for the SA_ constants.  */
# define SA_NOMASK    SA_NODEFER
# define SA_ONESHOT   SA_RESETHAND
# define SA_STACK     SA_ONSTACK
#endif

/* Values for the HOW argument to `sigprocmask'.  */
#define SIG_NOP	      0		/* 0 is unused to catch errors */
#define	SIG_BLOCK     1		/* Block signals.  */
#define	SIG_UNBLOCK   2		/* Unblock signals.  */
#define	SIG_SETMASK   3		/* Set the set of blocked signals.  */
#ifdef __USE_MISC
# define SIG_SETMASK32 256	/* Goodie from SGI for BSD compatibility:
				   set only the low 32 bit of the sigset.  */
#endif

#endif