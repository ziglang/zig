/* Signal number definitions.  Linux/MIPS version.
   Copyright (C) 1995-2020 Free Software Foundation, Inc.
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

#ifndef _BITS_SIGNUM_H
#define _BITS_SIGNUM_H 1

#ifndef _SIGNAL_H
#error "Never include <bits/signum.h> directly; use <signal.h> instead."
#endif

#include <bits/signum-generic.h>

/* Adjustments and additions to the signal number constants for
   Linux/MIPS.  */

#define SIGEMT		 7	/* Emulator trap.  */
#define SIGPWR		19	/* Power failure imminent.  */

#undef	SIGUSR1
#define SIGUSR1		16
#undef	SIGUSR2
#define SIGUSR2		17
#undef	SIGCHLD
#define SIGCHLD		18
#undef	SIGWINCH
#define SIGWINCH	20
#undef	SIGURG
#define SIGURG		21
#undef	SIGPOLL
#define SIGPOLL		22
#undef	SIGSTOP
#define SIGSTOP		23
#undef	SIGTSTP
#define SIGTSTP		24
#undef	SIGCONT
#define SIGCONT		25
#undef	SIGTTIN
#define SIGTTIN		26
#undef	SIGTTOU
#define SIGTTOU		27
#undef	SIGVTALRM
#define SIGVTALRM	28
#undef	SIGPROF
#define SIGPROF		29
#undef	SIGXCPU
#define SIGXCPU		30
#undef	SIGXFSZ
#define SIGXFSZ		31

#undef	__SIGRTMAX
#define __SIGRTMAX	127

#endif	/* <signal.h> included.  */