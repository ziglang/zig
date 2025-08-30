/* termios baud rate selection definitions.  Linux/powerpc version.
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
# define CBAUD	    000000377
# define CBAUDEX    000000020
# define CIBAUD     077600000
# define IBSHIFT    16
#endif

#define  __B57600   00020
#define  __B115200  00021
#define  __B230400  00022
#define  __B460800  00023
#define  __B500000  00024
#define  __B576000  00025
#define  __B921600  00026
#define  __B1000000 00027
#define  __B1152000 00030
#define  __B1500000 00031
#define  __B2000000 00032
#define  __B2500000 00033
#define  __B3000000 00034
#define  __B3500000 00035
#define  __B4000000 00036
#define  __BOTHER   00037