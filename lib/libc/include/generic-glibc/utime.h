/* Copyright (C) 1991-2023 Free Software Foundation, Inc.
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

/*
 *	POSIX Standard: 5.6.6 Set File Access and Modification Times  <utime.h>
 */

#ifndef	_UTIME_H
#define	_UTIME_H	1

#include <features.h>

__BEGIN_DECLS

#include <bits/types.h>

#if defined __USE_XOPEN || defined __USE_XOPEN2K
# include <bits/types/time_t.h>
#endif

/* Structure describing file times.  */
struct utimbuf
  {
#ifdef __USE_TIME_BITS64
    __time64_t actime;		/* Access time.  */
    __time64_t modtime;		/* Modification time.  */
#else
    __time_t actime;		/* Access time.  */
    __time_t modtime;		/* Modification time.  */
#endif
  };

/* Set the access and modification times of FILE to those given in
   *FILE_TIMES.  If FILE_TIMES is NULL, set them to the current time.  */
#ifndef __USE_TIME_BITS64
extern int utime (const char *__file,
		  const struct utimbuf *__file_times)
     __THROW __nonnull ((1));

#else
# ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (utime, (const char *__file,
                                   const struct utimbuf *__file_times),
                           __utime64);
# else
#  define utime __utime64
# endif
#endif

__END_DECLS

#endif /* utime.h */