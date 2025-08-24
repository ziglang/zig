/* termios c_cc symbolic constant definitions.  Linux/powerpc version.
   Copyright (C) 2019-2025 Free Software Foundation, Inc.
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
#define VINTR	0
#define VQUIT	1
#define VERASE	2
#define VKILL	3
#define VEOF	4
#define VMIN	5
#define VEOL	6
#define VTIME	7
#define VEOL2	8
#define VSWTC	9

#define VWERASE	10
#define VREPRINT	11
#define VSUSP		12
#define VSTART		13
#define VSTOP		14
#define VLNEXT		15
#define VDISCARD	16