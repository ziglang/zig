/* Time function internal interfaces.
   Copyright (C) 1997-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

#ifndef _SYS_TIME_H
# include <time/sys/time.h>

# ifndef _ISOMAC
extern int __gettimeofday (struct timeval *__tv,
			   struct timezone *__tz);
libc_hidden_proto (__gettimeofday)
libc_hidden_proto (gettimeofday)
extern int __settimeofday (const struct timeval *__tv,
			   const struct timezone *__tz)
	attribute_hidden;
extern int __adjtime (const struct timeval *__delta,
		      struct timeval *__olddelta);
extern int __getitimer (enum __itimer_which __which,
			struct itimerval *__value);
extern int __setitimer (enum __itimer_which __which,
			const struct itimerval *__restrict __new,
			struct itimerval *__restrict __old)
	attribute_hidden;
extern int __utimes (const char *__file, const struct timeval __tvp[2])
	attribute_hidden;
extern int __futimes (int fd, const struct timeval tvp[2]) attribute_hidden;

# endif
#endif
