/* Copyright (C) 1995-2023 Free Software Foundation, Inc.
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

#ifndef	_SYS_TIMEX_H
#define	_SYS_TIMEX_H	1

#include <features.h>
#include <sys/time.h>

/* These definitions from linux/timex.h as of 2.6.30.  */

#include <bits/timex.h>

#define NTP_API	4	/* NTP API version */

struct ntptimeval
{
  struct timeval time;	/* current time (ro) */
  long int maxerror;	/* maximum error (us) (ro) */
  long int esterror;	/* estimated error (us) (ro) */
  long int tai;		/* TAI offset (ro) */

  long int __glibc_reserved1;
  long int __glibc_reserved2;
  long int __glibc_reserved3;
  long int __glibc_reserved4;
};

/* Clock states (time_state) */
#define TIME_OK		0	/* clock synchronized, no leap second */
#define TIME_INS	1	/* insert leap second */
#define TIME_DEL	2	/* delete leap second */
#define TIME_OOP	3	/* leap second in progress */
#define TIME_WAIT	4	/* leap second has occurred */
#define TIME_ERROR	5	/* clock not synchronized */
#define TIME_BAD	TIME_ERROR /* bw compat */

/* Maximum time constant of the PLL.  */
#define MAXTC		6

__BEGIN_DECLS

#ifndef __USE_TIME_BITS64
extern int adjtimex (struct timex *__ntx) __THROW __nonnull ((1));
extern int ntp_gettimex (struct ntptimeval *__ntv) __THROW __nonnull ((1));

# ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (ntp_gettime, (struct ntptimeval *__ntv),
                           ntp_gettimex) __nonnull ((1));
# else
#  define ntp_gettime ntp_gettimex
# endif
extern int ntp_adjtime (struct timex *__tntx) __THROW __nonnull ((1));
#else
# ifdef __REDIRECT_NTH
extern int __REDIRECT_NTH (adjtimex, (struct timex *__ntx),
                           ___adjtimex64) __nonnull ((1));
extern int __REDIRECT_NTH (ntp_gettime, (struct ntptimeval *__ntv),
                           __ntp_gettime64) __nonnull ((1));
extern int __REDIRECT_NTH (ntp_gettimex, (struct ntptimeval *__ntv),
                           __ntp_gettimex64) __nonnull ((1));
extern int __REDIRECT_NTH (ntp_adjtime, (struct timex *__ntx),
                           ___adjtimex64) __nonnull ((1));
# else
#  define adjtimex ___adjtimex64
#  define ntp_adjtime ___adjtimex64
#  define ntp_gettime __ntp_gettime64
#  define ntp_gettimex __ntp_gettimex64
# endif
#endif

__END_DECLS

#endif /* sys/timex.h */
