/* termios c_cc symbolic constant definitions.  Linux/sparc version.
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
#define VINTR    0
#define VQUIT    1
#define VERASE   2
#define VKILL    3
#define VEOF     4
#define VEOL     5
#define VEOL2    6
#define VSWTC    7
#define VSTART   8
#define VSTOP    9
#define VSUSP    10
#define VDSUSP   11		/* SunOS POSIX nicety I do believe... */
#define VREPRINT 12
#define VDISCARD 13
#define VWERASE  14
#define VLNEXT   15

/* User apps assume vmin/vtime is shared with eof/eol */
#define VMIN     VEOF
#define VTIME    VEOL