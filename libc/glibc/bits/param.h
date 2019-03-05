/* Old-style Unix parameters and limits.  Stub version.
   Copyright (C) 1995-2019 Free Software Foundation, Inc.
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

#ifndef _SYS_PARAM_H
# error "Never use <bits/param.h> directly; include <sys/param.h> instead."
#endif

/* This header is expected to define a few particular macros.

   The traditional BSD macros that correspond directly to POSIX <limits.h>
   macros don't need to be defined here if <bits/local_lim.h> defines the
   POSIX limit macro, as the common <sys/param.h> code will define each
   traditional name to its POSIX name if available.

   This file should define at least:

        EXEC_PAGESIZE
*/
