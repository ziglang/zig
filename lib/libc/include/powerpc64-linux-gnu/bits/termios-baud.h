/* termios baud rate selection definitions.  Linux/powerpc version.
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
# error "Never include <bits/termios-baud.h> directly; use <termios.h> instead."
#endif

#ifdef __USE_MISC
# define CBAUD	0000377
# define CBAUDEX 0000020
# define CMSPAR   010000000000		/* mark or space (stick) parity */
# define CRTSCTS  020000000000		/* flow control */
#endif

#define  B57600   00020
#define  B115200  00021
#define  B230400  00022
#define  B460800  00023
#define  B500000  00024
#define  B576000  00025
#define  B921600  00026
#define  B1000000 00027
#define  B1152000 00030
#define  B1500000 00031
#define  B2000000 00032
#define  B2500000 00033
#define  B3000000 00034
#define  B3500000 00035
#define  B4000000 00036
#define __MAX_BAUD B4000000