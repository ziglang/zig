/* termios type and macro definitions.  Linux version.
   Copyright (C) 1993-2025 Free Software Foundation, Inc.
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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _TERMIOS_H
# error "Never include <bits/termios.h> directly; use <termios.h> instead."
#endif

typedef unsigned char	cc_t;
typedef unsigned int	speed_t;
typedef unsigned int	tcflag_t;

#ifdef _TERMIOS_H
# include <bits/termios-struct.h>
#endif

#include <bits/termios-c_cc.h>
#include <bits/termios-c_iflag.h>
#include <bits/termios-c_oflag.h>

/* c_cflag bit meaning */
#include <bits/termios-c_cflag.h>

#ifdef __USE_MISC
#define __B0	 0000000	/* hang up */
#define __B50	 0000001
#define __B75	 0000002
#define __B110	 0000003
#define __B134	 0000004
#define __B150	 0000005
#define __B200	 0000006
#define __B300	 0000007
#define __B600	 0000010
#define __B1200	 0000011
#define __B1800	 0000012
#define __B2400	 0000013
#define __B4800	 0000014
#define __B9600  0000015
#define __B19200 0000016
#define __B38400 0000017
#include <bits/termios-cbaud.h>

# define __EXTA	 __B19200
# define __EXTB	 __B38400
# define BOTHER  __BOTHER
#endif

#include <bits/termios-c_lflag.h>

#ifdef __USE_MISC
/* ioctl (fd, TIOCSERGETLSR, &result) where result may be as below */
# define TIOCSER_TEMT    0x01   /* Transmitter physically empty */
#endif

/* tcflow() and TCXONC use these */
#define	TCOOFF		0
#define	TCOON		1
#define	TCIOFF		2
#define	TCION		3

/* tcflush() and TCFLSH use these */
#define	TCIFLUSH	0
#define	TCOFLUSH	1
#define	TCIOFLUSH	2

#include <bits/termios-tcflow.h>

#include <bits/termios-misc.h>

#include <bits/termios-baud.h>