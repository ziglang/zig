/* Socket constants which vary among Linux architectures.
   Copyright (C) 2019-2021 Free Software Foundation, Inc.
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

#include <bits/timesize.h>

#define SOL_SOCKET 1
#define SO_ACCEPTCONN 30
#define SO_BROADCAST 6
#define SO_DONTROUTE 5
#define SO_ERROR 4
#define SO_KEEPALIVE 9
#define SO_LINGER 13
#define SO_OOBINLINE 10
#define SO_RCVBUF 8
#define SO_RCVLOWAT 18
#if (__TIMESIZE == 64 && __WORDSIZE == 32 \
     && (!defined __SYSCALL_WORDSIZE || __SYSCALL_WORDSIZE == 32))
# define SO_RCVTIMEO 66
#else
# define SO_RCVTIMEO 20
#endif
#define SO_REUSEADDR 2
#define SO_SNDBUF 7
#define SO_SNDLOWAT 19
#if (__TIMESIZE == 64 && __WORDSIZE == 32 \
     && (!defined __SYSCALL_WORDSIZE || __SYSCALL_WORDSIZE == 32))
# define SO_SNDTIMEO 67
#else
# define SO_SNDTIMEO 21
#endif
#define SO_TYPE 3