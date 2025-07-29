/* Signal number definitions.  Linux version.
   Copyright (C) 1995-2025 Free Software Foundation, Inc.
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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _BITS_SIGNUM_ARCH_H
#define _BITS_SIGNUM_ARCH_H 1

#ifndef _SIGNAL_H
#error "Never include <bits/signum-arch.h> directly; use <signal.h> instead."
#endif

/* Adjustments and additions to the signal number constants for
   most Linux systems.  */

#define SIGSTKFLT	16	/* Stack fault (obsolete).  */
#define SIGPWR		30	/* Power failure imminent.  */

/* Historical signals specified by POSIX. */
#define SIGBUS		 7	/* Bus error.  */
#define SIGSYS		31	/* Bad system call.  */

/* New(er) POSIX signals (1003.1-2008, 1003.1-2013).  */
#define SIGURG		23	/* Urgent data is available at a socket.  */
#define SIGSTOP		19	/* Stop, unblockable.  */
#define SIGTSTP		20	/* Keyboard stop.  */
#define SIGCONT		18	/* Continue.  */
#define SIGCHLD		17	/* Child terminated or stopped.  */
#define SIGTTIN		21	/* Background read from control terminal.  */
#define SIGTTOU		22	/* Background write to control terminal.  */
#define SIGPOLL		29	/* Pollable event occurred (System V).  */
#define SIGXFSZ		25	/* File size limit exceeded.  */
#define SIGXCPU		24	/* CPU time limit exceeded.  */
#define SIGVTALRM	26	/* Virtual timer expired.  */
#define SIGPROF		27	/* Profiling timer expired.  */
#define SIGUSR1		10	/* User-defined signal 1.  */
#define SIGUSR2		12	/* User-defined signal 2.  */

/* Nonstandard signals found in all modern POSIX systems
   (including both BSD and Linux).  */
#define SIGWINCH	28	/* Window size change (4.3 BSD, Sun).  */

/* Archaic names for compatibility.  */
#define SIGIO		SIGPOLL	/* I/O now possible (4.2 BSD).  */
#define SIGIOT		SIGABRT	/* IOT instruction, abort() on a PDP-11.  */
#define SIGCLD		SIGCHLD	/* Old System V name */

#define __SIGRTMIN	32
#define __SIGRTMAX	64

#endif	/* <signal.h> included.  */