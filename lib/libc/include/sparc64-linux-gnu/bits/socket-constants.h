/* Socket constants which vary among Linux architectures.  Version for SPARC.
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

#define SOL_SOCKET 65535
#define SO_ACCEPTCONN 32768
#define SO_BROADCAST 32
#define SO_DONTROUTE 16
#define SO_ERROR 4103
#define SO_KEEPALIVE 8
#define SO_LINGER 128
#define SO_OOBINLINE 256
#define SO_RCVBUF 4098
#define SO_RCVLOWAT 2048
#define SO_REUSEADDR 4
#define SO_SNDBUF 4097
#define SO_SNDLOWAT 4096
#define SO_TYPE 4104

#if __TIMESIZE == 64
# define SO_RCVTIMEO 8192
# define SO_SNDTIMEO 16384
# define SO_TIMESTAMP 29
# define SO_TIMESTAMPNS 33
# define SO_TIMESTAMPING 35
#else
# define SO_RCVTIMEO_OLD 8192
# define SO_SNDTIMEO_OLD 16384
# define SO_RCVTIMEO_NEW 68
# define SO_SNDTIMEO_NEW 69

# define SO_TIMESTAMP_OLD 0x001d
# define SO_TIMESTAMPNS_OLD 0x0021
# define SO_TIMESTAMPING_OLD 0x0023
# define SO_TIMESTAMP_NEW 0x0046
# define SO_TIMESTAMPNS_NEW 0x0042
# define SO_TIMESTAMPING_NEW 0x0043

# ifdef __USE_TIME_BITS64
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