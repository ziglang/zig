/* Definition of MINSIGSTKSZ and SIGSTKSZ.  Linux version.
   Copyright (C) 2020-2024 Free Software Foundation, Inc.
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

#ifndef _SIGNAL_H
# error "Never include <bits/sigstksz.h> directly; use <signal.h> instead."
#endif

#if defined __USE_DYNAMIC_STACK_SIZE && __USE_DYNAMIC_STACK_SIZE
# include <unistd.h>

/* Default stack size for a signal handler: sysconf (SC_SIGSTKSZ).  */
# undef SIGSTKSZ
# define SIGSTKSZ sysconf (_SC_SIGSTKSZ)

/* Minimum stack size for a signal handler: SIGSTKSZ.  */
# undef MINSIGSTKSZ
# define MINSIGSTKSZ SIGSTKSZ
#endif