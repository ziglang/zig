/* termios output mode definitions.  Linux/sparc version.
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
#define OPOST	0x00000001
#define OLCUC	0x00000002
#define ONLCR	0x00000004
#define OCRNL	0x00000008
#define ONOCR	0x00000010
#define ONLRET	0x00000020
#define OFILL	0x00000040
#define OFDEL	0x00000080
#if defined __USE_MISC || defined __USE_XOPEN
# define NLDLY	0x00000100
# define   NL0	0x00000000
# define   NL1	0x00000100
# define CRDLY	0x00000600
# define   CR0	0x00000000
# define   CR1	0x00000200
# define   CR2	0x00000400
# define   CR3	0x00000600
# define TABDLY	0x00001800
# define   TAB0	0x00000000
# define   TAB1	0x00000800
# define   TAB2	0x00001000
# define   TAB3	0x00001800
# define BSDLY	0x00002000
# define   BS0	0x00000000
# define   BS1	0x00002000
#define FFDLY	0x00008000
#define   FF0	0x00000000
#define   FF1	0x00008000
#endif
#define VTDLY	0x00004000
#define   VT0	0x00000000
#define   VT1	0x00004000

# if defined __USE_GNU
#define PAGEOUT 0x00010000	/* SUNOS specific */
#define WRAP    0x00020000	/* SUNOS specific */
# endif

#ifdef __USE_MISC
# define   XTABS	0x00001800
#endif