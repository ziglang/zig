/* Facilities specific to the PowerPC architecture on Linux
   Copyright (C) 2012-2025 Free Software Foundation, Inc.
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

#ifndef _BITS_PPC_H
#define _BITS_PPC_H

#ifndef _SYS_PLATFORM_PPC_H
# error "Never include this file directly; use <sys/platform/ppc.h> instead."
#endif

__BEGIN_DECLS

/* Read the time base frequency.   */
extern uint64_t __ppc_get_timebase_freq (void);

__END_DECLS

#endif