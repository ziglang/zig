/* Socket constants which vary among Linux architectures.  Version for POWER.
   Copyright (C) 2019-2024 Free Software Foundation, Inc.
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

#ifndef _SYS_SOCKET_H
# error "Never include <bits/socket-constants.h> directly; use <sys/socket.h> instead."
#endif

#define SOL_SOCKET 1
#define SO_ACCEPTCONN 30
#define SO_BROADCAST 6
#define SO_DONTROUTE 5
#define SO_ERROR 4
#define SO_KEEPALIVE 9
#define SO_LINGER 13
#define SO_OOBINLINE 10
#define SO_RCVBUF 8
#define SO_RCVLOWAT 16
#define SO_REUSEADDR 2
#define SO_SNDBUF 7
#define SO_SNDLOWAT 17
#define SO_TYPE 3

#if __TIMESIZE == 64
# define SO_RCVTIMEO 18
# define SO_SNDTIMEO 19
# define SO_TIMESTAMP 29
# define SO_TIMESTAMPNS 35
# define SO_TIMESTAMPING 37
#else
# define SO_RCVTIMEO_OLD 18
# define SO_SNDTIMEO_OLD 19
# define SO_RCVTIMEO_NEW 66
# define SO_SNDTIMEO_NEW 67

# define SO_TIMESTAMP_OLD 29
# define SO_TIMESTAMPNS_OLD 35
# define SO_TIMESTAMPING_OLD 37
# define SO_TIMESTAMP_NEW 63
# define SO_TIMESTAMPNS_NEW 64
# define SO_TIMESTAMPING_NEW 65

# ifdef __USE_TIME64_REDIRECTS
#  define SO_RCVTIMEO SO_RCVTIMEO_NEW
#  define SO_SNDTIMEO SO_SNDTIMEO_NEW
#  define SO_TIMESTAMP SO_TIMESTAMP_NEW
#  define SO_TIMESTAMPNS SO_TIMESTAMPNS_NEW
#  define SO_TIMESTAMPING SO_TIMESTAMPING_NEW
# else
#  define SO_RCVTIMEO SO_RCVTIMEO_OLD
#  define SO_SNDTIMEO SO_SNDTIMEO_OLD
#  define SO_TIMESTAMP SO_TIMESTAMP_OLD
#  define SO_TIMESTAMPNS SO_TIMESTAMPNS_OLD
#  define SO_TIMESTAMPING SO_TIMESTAMPING_OLD
# endif
#endif