/* termios baud rate selection definitions. Universal version for sane speed_t.
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
# error "Never include <bits/termios-baud.h> directly; use <termios.h> instead."
#endif

/* POSIX required baud rates */
#define B0		     0U		/* Hang up or ispeed == ospeed */
#define B50		    50U
#define B75		    75U
#define B110		   110U
#define B134		   134U		/* Really 134.5 baud by POSIX spec */
#define B150		   150U
#define B200		   200U
#define B300		   300U
#define B600		   600U
#define B1200		  1200U
#define B1800		  1800U
#define B2400		  2400U
#define B4800		  4800U
#define B9600		  9600U
#define	B19200		 19200U
#define	B38400		 38400U
#ifdef	__USE_MISC
# define EXTA		 B19200
# define EXTB		 B38400
#endif

/* Other baud rates, "nonstandard" but known to be used */
#define B7200		  7200U
#define B14400		 14400U
#define B28800		 28800U
#define B33600		 33600U
#define B57600		 57600U
#define B76800		 76800U
#define B115200		115200U
#define B153600		153600U
#define B230400		230400U
#define B307200		307200U
#define B460800		460800U
#define B500000		500000U
#define B576000		576000U
#define B614400		614400U
#define B921600		921600U
#define B1000000       1000000U
#define B1152000       1152000U
#define B1500000       1500000U
#define B2000000       2000000U
#define B2500000       2500000U
#define B3000000       3000000U
#define B3500000       3500000U
#define B4000000       4000000U
#define B5000000       5000000U
#define B10000000     10000000U

#ifdef __USE_GNU
#define SPEED_MAX  4294967295U	/* maximum valid speed_t value */
#endif
#define __MAX_BAUD 4294967295U	/* legacy alias for SPEED_MAX */