/* termios c_cc symbolic constant definitions.  Linux/mips version.
   Copyright (C) 2019-2023 Free Software Foundation, Inc.
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
# error "Never include <bits/termios-c_cc.h> directly; use <termios.h> instead."
#endif

/* c_cc characters */
#define VINTR		0	/* Interrupt character [ISIG].  */
#define VQUIT		1	/* Quit character [ISIG].  */
#define VERASE		2	/* Erase character [ICANON].  */
#define VKILL		3	/* Kill-line character [ICANON].  */
#define VMIN		4	/* Minimum number of bytes read at once [!ICANON].  */
#define VTIME		5	/* Time-out value (tenths of a second) [!ICANON].  */
#define VEOL2		6	/* Second EOL character [ICANON].  */
#define VSWTC		7
#define VSWTCH		VSWTC
#define VSTART		8	/* Start (X-ON) character [IXON, IXOFF].  */
#define VSTOP		9	/* Stop (X-OFF) character [IXON, IXOFF].  */
#define VSUSP		10	/* Suspend character [ISIG].  */
				/* VDSUSP is not supported on Linux. */
/* #define VDSUSP	11	/ * Delayed suspend character [ISIG].  */
#define VREPRINT	12	/* Reprint-line character [ICANON].  */
#define VDISCARD	13	/* Discard character [IEXTEN].  */
#define VWERASE		14	/* Word-erase character [ICANON].  */
#define VLNEXT		15	/* Literal-next character [IEXTEN].  */
#define VEOF		16	/* End-of-file character [ICANON].  */
#define VEOL		17	/* End-of-line character [ICANON].  */