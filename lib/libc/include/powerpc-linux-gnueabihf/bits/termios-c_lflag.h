/* termios local mode definitions.  Linux/powerpc version.
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
#define ISIG	0x00000080
#define ICANON	0x00000100
#if defined __USE_MISC || (defined __USE_XOPEN && !defined __USE_XOPEN2K)
# define XCASE	0x00004000
#endif
#define ECHO	0x00000008
#define ECHOE	0x00000002
#define ECHOK	0x00000004
#define ECHONL	0x00000010
#define NOFLSH	0x80000000
#define TOSTOP	0x00400000
#ifdef __USE_MISC
# define ECHOCTL	0x00000040
# define ECHOPRT	0x00000020
# define ECHOKE	0x00000001
# define FLUSHO	0x00800000
# define PENDIN	0x20000000
#endif
#define IEXTEN	0x00000400
#ifdef __USE_MISC
# define EXTPROC 0x10000000
#endif