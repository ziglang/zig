/* termios baud rate selection definitions.  Linux/sparc version.
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
# error "Never include <bits/termios-cbaud.h> directly; use <termios.h> instead."
#endif

#ifdef __USE_MISC
# define CBAUD   0x0000100f
# define CBAUDEX 0x00001000
# define CIBAUD	 0x100f0000	/* input baud rate */
# define IBSHIFT 16
#endif

#define  __B57600  0x00001001
#define  __B115200 0x00001002
#define  __B230400 0x00001003
#define  __B460800 0x00001004
#define  __B76800  0x00001005
#define  __B153600 0x00001006
#define  __B307200 0x00001007
#define  __B614400 0x00001008
#define  __B921600 0x00001009
#define  __B500000 0x0000100a
#define  __B576000 0x0000100b
#define __B1000000 0x0000100c
#define __B1152000 0x0000100d
#define __B1500000 0x0000100e
#define __B2000000 0x0000100f
#define __BOTHER   0x00001000