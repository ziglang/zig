/* termios output mode definitions.  Linux/powerpc version.
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
# error "Never include <bits/termios-c_oflag.h> directly; use <termios.h> instead."
#endif

/* c_oflag bits */
#define OPOST	0000001
#define ONLCR	0000002
#define OLCUC	0000004

#define OCRNL	0000010
#define ONOCR	0000020
#define ONLRET	0000040

#define OFILL	00000100
#define OFDEL	00000200
#if defined __USE_MISC || defined __USE_XOPEN
# define NLDLY	00001400
# define   NL0	00000000
# define   NL1	00000400
# if defined __USE_MISC
#  define   NL2	00001000
#  define   NL3	00001400
# endif
# define TABDLY	00006000
# define   TAB0	00000000
# define   TAB1	00002000
# define   TAB2	00004000
# define   TAB3	00006000
# define CRDLY	00030000
# define   CR0	00000000
# define   CR1	00010000
# define   CR2	00020000
# define   CR3	00030000
# define FFDLY	00040000
# define   FF0	00000000
# define   FF1	00040000
# define BSDLY	00100000
# define   BS0	00000000
# define   BS1	00100000
#endif
#define VTDLY	00200000
#define   VT0	00000000
#define   VT1	00200000

#ifdef __USE_MISC
# define XTABS	00006000
#endif