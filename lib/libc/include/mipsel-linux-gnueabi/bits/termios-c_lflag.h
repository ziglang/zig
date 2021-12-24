/* termios local mode definitions.  Linux/mips version.
   Copyright (C) 2019-2021 Free Software Foundation, Inc.
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

#ifndef _TERMIOS_H
# error "Never include <bits/termios-c_lflag.h> directly; use <termios.h> instead."
#endif

/* c_lflag bits */
#define ISIG	0000001		/* Enable signals.  */
#define ICANON	0000002		/* Do erase and kill processing.  */
#if defined __USE_MISC || (defined __USE_XOPEN && !defined __USE_XOPEN2K)
# define XCASE	0000004
#endif
#define ECHO	0000010		/* Enable echo.  */
#define ECHOE	0000020		/* Visual erase for ERASE.  */
#define ECHOK	0000040		/* Echo NL after KILL.  */
#define ECHONL	0000100		/* Echo NL even if ECHO is off.  */
#define NOFLSH	0000200		/* Disable flush after interrupt.  */
#define IEXTEN	0000400		/* Enable DISCARD and LNEXT.  */
#ifdef __USE_MISC
# define ECHOCTL 0001000	/* Echo control characters as ^X.  */
# define ECHOPRT 0002000	/* Hardcopy visual erase.  */
# define ECHOKE	 0004000	/* Visual erase for KILL.  */
# define FLUSHO	0020000
# define PENDIN	0040000		/* Retype pending input (state).  */
#endif
#define TOSTOP	0100000		/* Send SIGTTOU for background output.  */
#define ITOSTOP	TOSTOP
#ifdef __USE_MISC
# define EXTPROC 0200000
#endif