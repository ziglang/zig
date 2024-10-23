/* termios baud rate selection definitions.  Linux/sparc version.
   Copyright (C) 2019-2024 Free Software Foundation, Inc.
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
# error "Never include <bits/termios-baud.h> directly; use <termios.h> instead."
#endif

#ifdef __USE_MISC
# define CBAUD   0x0000100f
# define CBAUDEX 0x00001000
# define CIBAUD	 0x100f0000	/* input baud rate (not used) */
# define CMSPAR  0x40000000	/* mark or space (stick) parity */
# define CRTSCTS 0x80000000	/* flow control */
#endif

#define  B57600  0x00001001
#define  B115200 0x00001002
#define  B230400 0x00001003
#define  B460800 0x00001004
#define  B76800  0x00001005
#define  B153600 0x00001006
#define  B307200 0x00001007
#define  B614400 0x00001008
#define  B921600 0x00001009
#define  B500000 0x0000100a
#define  B576000 0x0000100b
#define B1000000 0x0000100c
#define B1152000 0x0000100d
#define B1500000 0x0000100e
#define B2000000 0x0000100f
#define __MAX_BAUD B2000000